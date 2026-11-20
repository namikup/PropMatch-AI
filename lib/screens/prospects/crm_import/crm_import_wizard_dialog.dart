import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../providers/app_state_provider.dart';
import '../../../services/crm_import/batch_importer.dart';
import '../../../services/crm_import/column_mapping.dart';
import '../../../services/crm_import/duplicate_detector.dart';
import '../../../services/crm_import/file_parser.dart';
import '../../../services/crm_import/import_validator.dart';
import '../../../services/crm_import/report_downloader.dart';

enum PreviewFilterTab { all, valid, duplicates, warnings, errors }

/// Multi-step production modal wizard for importing Malaysian CRM buyer enquiry
/// records into the agent-scoped Prospect Database under PDPA 2010 compliance.
class CRMImportWizardDialog extends StatefulWidget {
  const CRMImportWizardDialog({super.key});

  @override
  State<CRMImportWizardDialog> createState() => _CRMImportWizardDialogState();
}

class _CRMImportWizardDialogState extends State<CRMImportWizardDialog> {
  int _currentStep = 0;

  // Step 1: Input state
  int _inputTab = 0; // 0: File upload, 1: Paste text
  bool _isPickingFile = false;
  String? _selectedFileName;
  int? _selectedFileSize;
  ParsedTable? _parsedTable;
  String? _fileValidationError;
  final TextEditingController _pasteTextController = TextEditingController();

  // Step 2: Mapping state
  ColumnMappingConfig _mappingConfig = ColumnMappingConfig();

  // Step 3: Preview & Deduplication state
  DuplicateResolutionStrategy _duplicateStrategy = DuplicateResolutionStrategy.skip;
  PreviewFilterTab _previewFilter = PreviewFilterTab.all;
  ImportPreviewReport? _previewReport;

  // Step 4: Execution state
  bool _isExecuting = false;
  BatchImportProgress? _importProgress;
  BatchImportResult? _importResult;
  String? _executionError;

  @override
  void dispose() {
    _parsedTable = null;
    _pasteTextController.clear();
    _pasteTextController.dispose();
    super.dispose();
  }

  // --- SAMPLE DATA GENERATOR (Data Minimization: No NRIC/Passport collected) ---
  static const String _malaysianSampleCsv =
      'Full Name,Phone Number,Email Address,Preferred Location,State,Min Budget,Max Budget,Property Type,Purpose,Timeline,Consent Status,Consent Evidence,Notes\n'
      'Ahmad Faiz bin Razak,012-3456789,ahmad.faiz@gmail.com,Mont Kiara,Kuala Lumpur,RM 650000,RM 850000,Condominium,Own Stay,1-3 months,Pending Consent,WhatsApp enquiry 14/11/2026,Looking for 3-bedder near Garden International School\n'
      'Tan Wei Lun,016-9876543,weilun.tan@yahoo.com,Petaling Jaya,Selangor,RM 800000,RM 1200000,Semi-D / Landed,Own Stay,3-6 months,Opted In,Signed showroom visitor register 10/11/2026,Wants freehold unit near LRT\n'
      'Muthu Kumar a/l Raman,019-2233445,muthu.kr@outlook.com,Cyberjaya,Selangor,RM 450000,RM 600000,Serviced Residence,Investment,Ready now,Pending Consent,iProperty enquiry form,High rental yield target near university\n'
      'Siti Nurhaliza binti Osman,011-12345678,siti.osman@gmail.com,KLCC,Kuala Lumpur,RM 1200000,RM 1800000,Luxury Condominium,Investment,Immediate,Opted In,Email enquiry with consent clause 02/11/2026,Expat tenant friendly preferred\n'
      'Chong Kah Wai,017-8899001,kahwai.chong@hotmail.com,Bayan Lepas,Penang,RM 550000,RM 750000,Condominium,Own Stay,6-12 months,Pending Consent,,First-time buyer looking for new launch\n'
      'Noor Azlina binti Hashim,018-7766554,azlina.hashim@gov.my,Putrajaya,Putrajaya,RM 500000,RM 700000,Townhouse,Own Stay,3-6 months,Opted Out,Requested removal on 05/11/2026,Do not contact for marketing';

  // --- ACTIONS ---

  Future<void> _pickFile() async {
    setState(() {
      _isPickingFile = true;
      _fileValidationError = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'xlsx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final name = file.name;

        if (bytes == null || bytes.isEmpty) {
          setState(() {
            _fileValidationError = 'Selected file contains no data or could not be read.';
          });
          return;
        }

        final validation = CRMFileParser.validateFile(fileName: name, bytes: bytes);
        if (!validation.isValid) {
          setState(() {
            _fileValidationError = validation.errorMessage;
          });
          return;
        }

        final parsed = await CRMFileParser.parseFile(fileName: name, bytes: bytes);
        if (parsed.rows.isEmpty) {
          setState(() {
            _fileValidationError = 'File contains headers but no valid data rows.';
          });
          return;
        }

        setState(() {
          _selectedFileName = name;
          _selectedFileSize = bytes.length;
          _parsedTable = parsed;
          _fileValidationError = null;
          _mappingConfig = ColumnMappingConfig.autoDetect(parsed.headers);
        });
      }
    } catch (e) {
      setState(() {
        _fileValidationError = 'Error processing file: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _parsePastedText() async {
    final text = _pasteTextController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _fileValidationError = 'Please paste CSV or TSV data before parsing.';
      });
      return;
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(text));
      final validation = CRMFileParser.validateFile(fileName: 'pasted_data.csv', bytes: bytes);
      if (!validation.isValid) {
        setState(() {
          _fileValidationError = validation.errorMessage;
        });
        return;
      }

      final parsed = await CRMFileParser.parseFile(fileName: 'pasted_data.csv', bytes: bytes);
      if (parsed.rows.isEmpty) {
        setState(() {
          _fileValidationError = 'No valid rows found in pasted text.';
        });
        return;
      }

      setState(() {
        _selectedFileName = 'Pasted CRM Text';
        _selectedFileSize = bytes.length;
        _parsedTable = parsed;
        _fileValidationError = null;
        _mappingConfig = ColumnMappingConfig.autoDetect(parsed.headers);
      });
    } catch (e) {
      setState(() {
        _fileValidationError = 'Parsing error: $e';
      });
    }
  }

  void _loadSampleData() {
    _pasteTextController.text = _malaysianSampleCsv;
    _parsePastedText();
  }

  void _runValidation() {
    if (_parsedTable == null) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    final detector = CRMDuplicateDetector(
      currentOwnerId: appState.currentOwnerId,
      existingProspects: appState.allProspects,
      existingBuyers: appState.allBuyers,
    );

    final report = CRMImportValidator.validateTable(
      table: _parsedTable!,
      mapping: _mappingConfig,
      duplicateDetector: detector,
      ownerId: appState.currentOwnerId,
      sourceName: _selectedFileName ?? 'CRM Import',
    );

    setState(() {
      _previewReport = report;
      _currentStep = 2;
    });
  }

  void _onStrategyChanged(DuplicateResolutionStrategy strategy) {
    setState(() {
      _duplicateStrategy = strategy;
    });
    // Re-run validation so the preview reflects the selected duplicate resolution
    if (_parsedTable != null) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final detector = CRMDuplicateDetector(
        currentOwnerId: appState.currentOwnerId,
        existingProspects: appState.allProspects,
        existingBuyers: appState.allBuyers,
      );

      setState(() {
        _previewReport = CRMImportValidator.validateTable(
          table: _parsedTable!,
          mapping: _mappingConfig,
          duplicateDetector: detector,
          ownerId: appState.currentOwnerId,
          sourceName: _selectedFileName ?? 'CRM Import',
        );
      });
    }
  }

  Future<void> _executeImport() async {
    if (_previewReport == null) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    setState(() {
      _currentStep = 3;
      _isExecuting = true;
      _executionError = null;
    });

    try {
      final result = await appState.executeProspectImportJob(
        preview: _previewReport!,
        duplicateStrategy: _duplicateStrategy,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _importProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          // Purge raw parsed file table and text buffer from volatile memory upon completion
          _parsedTable = null;
          _pasteTextController.clear();
          _importResult = result;
          _isExecuting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _executionError = e.toString();
          _isExecuting = false;
        });
      }
    }
  }

  void _downloadErrorReport() {
    if (_previewReport == null) return;
    final csv = _previewReport!.generateErrorReportCsv();
    CRMReportDownloader.downloadCsv(
      content: csv,
      filename: 'prospect_import_audit_report_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloaded privacy-masked error & audit report CSV.'),
        backgroundColor: AppTheme.secondary,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _copyErrorReportToClipboard() {
    if (_previewReport == null) return;
    final csv = _previewReport!.generateErrorReportCsv();
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audit report copied to clipboard.'),
        backgroundColor: AppTheme.secondary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width.clamp(600.0, 960.0);
    final dialogHeight = screenSize.height.clamp(550.0, 780.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildStepper(),
            const Divider(height: 1, color: AppTheme.cardBorder),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: _buildCurrentStepContent(),
              ),
            ),
            const Divider(height: 1, color: AppTheme.cardBorder),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // --- HEADER & STEPPER ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingMd,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMedium)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRM Buyer Enquiry Import Engine',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Import external CSV, TSV or XLSX leads into your agent-scoped Prospect Database under Malaysian PDPA 2010 rules.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: _isExecuting ? null : () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final steps = [
      '1. File Upload',
      '2. Column Mapping',
      '3. Preview & Deduplication',
      '4. Batch Execution',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12),
      color: AppTheme.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              return Container(
                width: 32,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                height: 1.5,
                color: AppTheme.cardBorder,
              );
            }
            final stepIndex = index ~/ 2;
            final isActive = _currentStep == stepIndex;
            final isCompleted = _currentStep > stepIndex;

            Color badgeColor;
            Color textColor;
            if (isCompleted) {
              badgeColor = AppTheme.secondary;
              textColor = AppTheme.textPrimary;
            } else if (isActive) {
              badgeColor = AppTheme.primary;
              textColor = AppTheme.primary;
            } else {
              badgeColor = AppTheme.textHint.withValues(alpha: 0.5);
              textColor = AppTheme.textSecondary;
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${stepIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  steps[stepIndex],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // --- STEP CONTENT ROUTER ---

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Upload();
      case 1:
        return _buildStep2Mapping();
      case 2:
        return _buildStep3Preview();
      case 3:
        return _buildStep4Execution();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: FILE UPLOAD & INPUT ---

  Widget _buildStep1Upload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_present_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('Upload File (.csv, .tsv, .xlsx)'),
                ],
              ),
              selected: _inputTab == 0,
              onSelected: (selected) {
                if (selected) setState(() => _inputTab = 0);
              },
            ),
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.paste_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('Paste Raw Text / Demo Data'),
                ],
              ),
              selected: _inputTab == 1,
              onSelected: (selected) {
                if (selected) setState(() => _inputTab = 1);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_fileValidationError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _fileValidationError!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: _inputTab == 0 ? _buildFileUploadTab() : _buildPasteTextTab(),
        ),

        if (_parsedTable != null) _buildFileSummaryCard(),
      ],
    );
  }

  Widget _buildFileUploadTab() {
    return Center(
      child: InkWell(
        onTap: _isPickingFile ? null : _pickFile,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: _parsedTable != null ? AppTheme.secondary : AppTheme.cardBorder,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPickingFile) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Reading and validating file...', style: TextStyle(color: AppTheme.textSecondary)),
              ] else if (_parsedTable != null) ...[
                const Icon(Icons.check_circle_outline, size: 48, color: AppTheme.secondary),
                const SizedBox(height: 12),
                Text(
                  _selectedFileName ?? 'File loaded',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_parsedTable!.rows.length} rows parsed successfully • Tap to select another file',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ] else ...[
                const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primary),
                const SizedBox(height: 12),
                const Text(
                  'Click to Browse & Upload CRM File',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Supports Comma/Tab Separated CSV, TSV or Microsoft Excel (.xlsx) up to 5MB',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Select File from Disk'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasteTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Paste CSV or TSV Data (with headers):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            TextButton.icon(
              onPressed: _loadSampleData,
              icon: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.accent),
              label: const Text(
                'Load Malaysian Demo Leads',
                style: TextStyle(fontSize: 12, color: AppTheme.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _pasteTextController,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: InputDecoration(
              hintText: 'Full Name,Phone Number,Email,Preferred Location,State,Min Budget,Max Budget\n'
                  'Ahmad Faiz,012-3456789,ahmad@gmail.com,Mont Kiara,Kuala Lumpur,650000,850000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _parsePastedText,
            icon: const Icon(Icons.table_view, size: 16),
            label: const Text('Parse Pasted Text'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildFileSummaryCard() {
    final file = _parsedTable!;
    final sizeKb = (_selectedFileSize ?? 0) / 1024;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'File: ${_selectedFileName ?? 'Uploaded'} (${sizeKb.toStringAsFixed(1)} KB) • '
              '${file.headers.length} Columns • ${file.rows.length} Data Rows',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: COLUMN MAPPING ---

  Widget _buildStep2Mapping() {
    if (_parsedTable == null) return const SizedBox.shrink();
    final headers = _parsedTable!.headers;
    final row1 = _parsedTable!.rows.isNotEmpty ? _parsedTable!.rows.first : <String?>[];

    final isFullNameMapped = _mappingConfig.hasRequiredFields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Map Source Columns to PropMatch AI Fields',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Full Name is mandatory. All other fields enhance buyer matching and PDPA compliance.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _mappingConfig = ColumnMappingConfig.autoDetect(headers);
                });
              },
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reset to Auto-detected'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!isFullNameMapped)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 18),
                SizedBox(width: 8),
                Text(
                  'Please map the "Prospect Full Name" field before continuing.',
                  style: TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.cardBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              itemCount: CRMColumnMappingRegistry.definitions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
              itemBuilder: (context, index) {
                final fieldDef = CRMColumnMappingRegistry.definitions[index];
                final field = fieldDef.field;
                final currentMappedHeader = _mappingConfig.getHeader(field);

                // Value preview from row 1
                String previewValue = '—';
                if (currentMappedHeader != null) {
                  final colIdx = headers.indexOf(currentMappedHeader);
                  if (colIdx != -1 && colIdx < row1.length && row1[colIdx] != null) {
                    previewValue = row1[colIdx]!;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Target field metadata
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  fieldDef.label,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                if (fieldDef.isRequired) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'REQUIRED',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.error),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fieldDef.description,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Dropdown selector
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey('${field.name}_$currentMappedHeader'),
                          initialValue: currentMappedHeader,
                          isDense: true,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          hint: const Text('< Skip / Unmapped >', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('< Skip / Unmapped >', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                            ),
                            ...headers.map((h) => DropdownMenuItem<String?>(
                                  value: h,
                                  child: Text(h, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _mappingConfig.setMapping(field, val);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Sample preview
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            previewValue.isEmpty ? '—' : previewValue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 3: PREVIEW & DEDUPLICATION ---

  Widget _buildStep3Preview() {
    final report = _previewReport;
    if (report == null) return const Center(child: CircularProgressIndicator());

    // Filter rows based on selected tab
    List<ImportRowValidation> filteredRows;
    switch (_previewFilter) {
      case PreviewFilterTab.all:
        filteredRows = report.rows;
        break;
      case PreviewFilterTab.valid:
        filteredRows = report.rows.where((r) => r.isValid && !r.isDuplicate && r.warnings.isEmpty).toList();
        break;
      case PreviewFilterTab.duplicates:
        filteredRows = report.rows.where((r) => r.isDuplicate).toList();
        break;
      case PreviewFilterTab.warnings:
        filteredRows = report.rows.where((r) => r.warnings.isNotEmpty).toList();
        break;
      case PreviewFilterTab.errors:
        filteredRows = report.rows.where((r) => !r.isValid).toList();
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI banner
        _buildPreviewKpiCards(report),
        const SizedBox(height: 12),

        // Duplicate resolution selector
        _buildDuplicateStrategyCard(report),
        const SizedBox(height: 12),

        // Filter tabs and actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('All (${report.totalRows})', PreviewFilterTab.all),
                _buildFilterChip('Valid (${report.validCount})', PreviewFilterTab.valid),
                _buildFilterChip('Duplicates (${report.duplicateCount})', PreviewFilterTab.duplicates),
                _buildFilterChip('Warnings (${report.warningCount})', PreviewFilterTab.warnings),
                _buildFilterChip('Errors (${report.invalidCount})', PreviewFilterTab.errors),
              ],
            ),
            if (report.invalidCount > 0 || report.warningCount > 0)
              OutlinedButton.icon(
                onPressed: _downloadErrorReport,
                icon: const Icon(Icons.download_outlined, size: 14),
                label: const Text('Export Error Report'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Preview Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.cardBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: filteredRows.isEmpty
                ? const Center(
                    child: Text('No records match the selected filter.', style: TextStyle(color: AppTheme.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: filteredRows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
                    itemBuilder: (context, index) {
                      final row = filteredRows[index];
                      return _buildPreviewRowTile(row);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewKpiCards(ImportPreviewReport report) {
    return Row(
      children: [
        _buildKpiCard('Total Rows', '${report.totalRows}', AppTheme.primary),
        const SizedBox(width: 8),
        _buildKpiCard('Valid', '${report.validCount}', AppTheme.secondary),
        const SizedBox(width: 8),
        _buildKpiCard('Duplicates', '${report.duplicateCount}', Colors.blueGrey),
        const SizedBox(width: 8),
        _buildKpiCard('Warnings', '${report.warningCount}', AppTheme.accent),
        const SizedBox(width: 8),
        _buildKpiCard('Errors', '${report.invalidCount}', AppTheme.error),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicateStrategyCard(ImportPreviewReport report) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline, size: 20, color: AppTheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicate Resolution Strategy',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  'Matched against your existing prospects and CRM buyers by normalized phone/email.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: SegmentedButton<DuplicateResolutionStrategy>(
              segments: const [
                ButtonSegment(
                  value: DuplicateResolutionStrategy.skip,
                  label: Text('Skip', style: TextStyle(fontSize: 11)),
                  tooltip: 'Skip duplicate rows and preserve existing records',
                ),
                ButtonSegment(
                  value: DuplicateResolutionStrategy.merge,
                  label: Text('Merge', style: TextStyle(fontSize: 11)),
                  tooltip: 'Merge new details into existing prospect',
                ),
                ButtonSegment(
                  value: DuplicateResolutionStrategy.importAnyway,
                  label: Text('Import Anyway', style: TextStyle(fontSize: 11)),
                  tooltip: 'Create duplicate record with new ID',
                ),
              ],
              selected: {_duplicateStrategy},
              onSelectionChanged: (set) => _onStrategyChanged(set.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, PreviewFilterTab tab) {
    final isSelected = _previewFilter == tab;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _previewFilter = tab);
      },
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPreviewRowTile(ImportRowValidation row) {
    final candidate = row.candidate;

    Color badgeColor;
    String statusLabel;
    IconData statusIcon;

    if (!row.isValid) {
      badgeColor = AppTheme.error;
      statusLabel = row.errors.join('; ');
      statusIcon = Icons.error_outline;
    } else if (row.isDuplicate) {
      badgeColor = Colors.blueGrey;
      statusLabel = 'Duplicate (${row.duplicateInfo.matchedField}) • Strategy: ${_duplicateStrategy.name.toUpperCase()}';
      statusIcon = Icons.copy;
    } else if (row.warnings.isNotEmpty) {
      badgeColor = AppTheme.accent;
      statusLabel = row.warnings.join('; ');
      statusIcon = Icons.warning_amber_rounded;
    } else {
      badgeColor = AppTheme.secondary;
      statusLabel = 'Valid record';
      statusIcon = Icons.check_circle_outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Row index
          SizedBox(
            width: 32,
            child: Text(
              '#${row.rowIndex}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),

          // Name and Contact
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate?.fullName ?? 'Missing Name',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  '${candidate?.phone.isNotEmpty == true ? candidate!.phone : '—'} • ${candidate?.email.isNotEmpty == true ? candidate!.email : '—'}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Location & Budget
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${candidate?.preferredLocations.isNotEmpty == true ? candidate!.preferredLocations.first : '—'}${candidate?.preferredState.isNotEmpty == true ? ", ${candidate!.preferredState}" : ""}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  candidate != null ? 'RM ${(candidate.budgetMin / 1000).toStringAsFixed(0)}k - ${(candidate.budgetMax / 1000).toStringAsFixed(0)}k' : '—',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Consent Badge
          Expanded(
            flex: 2,
            child: _buildConsentBadge(candidate?.contactEligibility ?? 'Pending Consent'),
          ),

          // Status & Flags
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Icon(statusIcon, size: 14, color: badgeColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentBadge(String contactEligibility) {
    Color color;
    String label;
    switch (contactEligibility) {
      case 'Eligible':
        color = AppTheme.secondary;
        label = 'Consent Verified';
        break;
      case 'Pending Consent':
        color = AppTheme.accent;
        label = 'Pending Consent';
        break;
      case 'Do Not Contact':
        color = AppTheme.error;
        label = 'Do Not Contact';
        break;
      default:
        color = Colors.grey;
        label = 'Ineligible';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  // --- STEP 4: EXECUTION & RESULTS ---

  Widget _buildStep4Execution() {
    if (_isExecuting) {
      final progress = _importProgress;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              progress?.currentOperation ?? 'Executing CRM batch import...',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 320,
              child: LinearProgressIndicator(
                value: progress?.percentage,
                backgroundColor: AppTheme.cardBorder,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            if (progress != null)
              Text(
                'Processed ${progress.current} of ${progress.total} records (${(progress.percentage * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
          ],
        ),
      );
    }

    if (_executionError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            const Text(
              'Import Failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _executionError!,
              style: const TextStyle(fontSize: 13, color: AppTheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => setState(() => _currentStep = 2),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return to Preview'),
            ),
          ],
        ),
      );
    }

    final result = _importResult;
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.secondary, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Batch Ingestion Complete',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Successfully processed ${result.totalRows} records into your agent-scoped Prospect Database.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Metrics Breakdown
        Row(
          children: [
            _buildResultMetricCard('Imported', '${result.importedCount}', AppTheme.secondary, Icons.person_add),
            const SizedBox(width: 12),
            _buildResultMetricCard('Merged', '${result.mergedCount}', Colors.blue, Icons.merge),
            const SizedBox(width: 12),
            _buildResultMetricCard('Skipped', '${result.skippedDuplicatesCount}', Colors.blueGrey, Icons.skip_next),
            const SizedBox(width: 12),
            _buildResultMetricCard('Errors', '${result.errorCount}', AppTheme.error, Icons.warning),
          ],
        ),
        const SizedBox(height: 16),

        // Job details & PDPA Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audit Job Reference: ${result.jobId}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateTime.now().toLocal().toString().split('.').first,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.security, size: 16, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Consent & Privacy Control Notice: Newly ingested prospects default to "Pending Consent" and are marked Contact Ineligible until documented, purpose-scoped consent has been verified by the agent.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),

        // Report buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _downloadErrorReport,
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Download Audit Report (CSV)'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _copyErrorReportToClipboard,
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('Copy Report to Clipboard'),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildResultMetricCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- FOOTER CONTROLS ---

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12),
      color: AppTheme.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Cancel or Back
          if (_currentStep == 0)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            )
          else if (_currentStep == 1)
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to File'),
            )
          else if (_currentStep == 2)
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Mapping'),
            )
          else
            const SizedBox.shrink(),

          // Right: Action
          if (_currentStep == 0)
            FilledButton.icon(
              onPressed: _parsedTable == null || _parsedTable!.rows.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _currentStep = 1;
                      });
                    },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Continue to Mapping'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            )
          else if (_currentStep == 1)
            FilledButton.icon(
              onPressed: !_mappingConfig.hasRequiredFields ? null : _runValidation,
              icon: const Icon(Icons.rule, size: 16),
              label: const Text('Preview & Validate'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            )
          else if (_currentStep == 2)
            FilledButton.icon(
              onPressed: _previewReport == null ||
                      (_previewReport!.validCount == 0 &&
                          !(_duplicateStrategy != DuplicateResolutionStrategy.skip && _previewReport!.duplicateCount > 0))
                  ? null
                  : _executeImport,
              icon: const Icon(Icons.cloud_upload, size: 16),
              label: Text('Execute Ingestion (${_calculateIngestibleCount()} records)'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
            )
          else if (_currentStep == 3 && !_isExecuting)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('View Prospect Database'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  int _calculateIngestibleCount() {
    final report = _previewReport;
    if (report == null) return 0;
    if (_duplicateStrategy == DuplicateResolutionStrategy.skip) {
      return report.validCount - report.duplicateCount;
    }
    return report.validCount;
  }
}
