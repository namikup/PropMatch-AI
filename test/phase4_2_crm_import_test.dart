import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:propmatch_ai/models/buyer_model.dart';
import 'package:propmatch_ai/models/prospect_model.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/repositories/prospect_repository.dart';
import 'package:propmatch_ai/screens/prospects/crm_import/crm_import_wizard_dialog.dart';
import 'package:propmatch_ai/services/crm_import/batch_importer.dart';
import 'package:propmatch_ai/services/crm_import/column_mapping.dart';
import 'package:propmatch_ai/services/crm_import/consent_mapper.dart';
import 'package:propmatch_ai/services/crm_import/duplicate_detector.dart';
import 'package:propmatch_ai/services/crm_import/file_parser.dart';
import 'package:propmatch_ai/services/crm_import/import_validator.dart';
import 'package:propmatch_ai/services/crm_import/normalizer.dart';

void main() {
  group('Phase 4.2 & 4.2.1: CRM File Parser & XLSX/CSV Verification Tests', () {
    test('Rejects empty file bytes', () {
      final res = CRMFileParser.validateFile(
        fileName: 'empty.csv',
        bytes: Uint8List(0),
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('empty'));
    });

    test('Rejects file exceeding 5MB limit', () {
      final largeBytes = Uint8List(5 * 1024 * 1024 + 100);
      final res = CRMFileParser.validateFile(
        fileName: 'large.csv',
        bytes: largeBytes,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('exceeds the maximum allowed limit of 5.0 MB'));
    });

    test('Rejects unsupported file format (.pdf)', () {
      final res = CRMFileParser.validateFile(
        fileName: 'buyers.pdf',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Unsupported file extension'));
    });

    test('Rejects corrupted XLSX with invalid magic bytes', () {
      final fakeXlsx = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);
      final res = CRMFileParser.validateFile(
        fileName: 'corrupted.xlsx',
        bytes: fakeXlsx,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('OpenXML binary signature'));
    });

    test('Rejects disguised ZIP/XLSX binary uploaded with .csv extension', () {
      final zipHeader = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]);
      final res = CRMFileParser.validateFile(
        fileName: 'disguised.csv',
        bytes: zipHeader,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('binary ZIP/XLSX signature'));
    });

    test('Accepts genuine XLSX magic bytes (PK 0x03 0x04) and rejects malformed zip archive during parse', () async {
      final malformedZipHeader = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0xFF, 0xEE]);
      final res = CRMFileParser.validateFile(
        fileName: 'valid_header.xlsx',
        bytes: malformedZipHeader,
      );
      expect(res.isValid, isTrue);
      expect(res.detectedFormat, equals('xlsx'));

      await expectLater(
        () => CRMFileParser.parseFile(fileName: 'valid_header.xlsx', bytes: malformedZipHeader),
        throwsA(isA<FormatException>()),
      );
    });

    test('Genuinely parses multi-worksheet XLSX file, skipping empty sheet/rows and extracting numeric/text cells', () async {
      final excel = Excel.createExcel();
      // Sheet1 is created by default; leave it with only blank cells
      final sheet1 = excel['Sheet1'];
      sheet1.appendRow([TextCellValue(''), TextCellValue('   ')]);

      // Add a second worksheet 'Malaysian Leads' with real headers, empty rows, and numeric cells
      final leadsSheet = excel['Malaysian Leads'];
      leadsSheet.appendRow([TextCellValue(''), TextCellValue('')]); // Leading empty row
      leadsSheet.appendRow([
        TextCellValue('Full Name'),
        TextCellValue(''), // Intermediate empty header column
        TextCellValue('Phone Number'),
        TextCellValue('Max Budget'),
      ]);
      leadsSheet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue('')]); // Empty middle row
      leadsSheet.appendRow([
        TextCellValue('Dato Ahmad Faiz'),
        TextCellValue('Ignored col'),
        IntCellValue(123456789), // Numeric phone cell without leading zero
        DoubleCellValue(850000.0), // Float budget cell
      ]);
      leadsSheet.appendRow([
        TextCellValue('Tan Wei Lun'),
        TextCellValue(''),
        TextCellValue('016-9876543'),
        IntCellValue(1200000),
      ]);

      final encodedBytes = Uint8List.fromList(excel.encode()!);
      final parsed = await CRMFileParser.parseFile(
        fileName: 'multi_sheet_leads.xlsx',
        bytes: encodedBytes,
      );

      expect(parsed.fileType, equals('xlsx'));
      expect(parsed.activeSheet, equals('Malaysian Leads'));
      expect(parsed.availableSheets, containsAll(['Sheet1', 'Malaysian Leads']));
      // Intermediate empty header is preserved as Column_2 so Phone Number stays at index 2!
      expect(parsed.headers, equals(['Full Name', 'Column_2', 'Phone Number', 'Max Budget']));
      expect(parsed.rows.length, equals(2));
      expect(parsed.rows[0][0], equals('Dato Ahmad Faiz'));
      expect(parsed.rows[0][2], equals('123456789'));
      expect(parsed.rows[0][3], equals('850000'));
      expect(parsed.rows[1][0], equals('Tan Wei Lun'));
      expect(parsed.rows[1][2], equals('016-9876543'));
    });

    test('Rejects CSV with binary null bytes', () {
      final binaryBytes = Uint8List.fromList([0x48, 0x65, 0x00, 0x00, 0x00, 0x6C]);
      final res = CRMFileParser.validateFile(
        fileName: 'binary.csv',
        bytes: binaryBytes,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('binary format'));
    });

    test('Parses CSV with UTF-8 BOM, escaped quotes, multiline cells, empty intermediate headers, and inconsistent row lengths', () async {
      const csvContent =
          '\uFEFFFull Name,,Phone Number,Notes\n'
          '"Ahmad ""Dato"" Faiz, bin Razak",unmapped,012-3456789,"Wants 3-room condo,\nnear LRT station"\n'
          '   ,   ,   ,   \n' // Empty row
          'Tan Wei Lun,,016-9876543\n'; // Short row missing Notes column

      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final table = await CRMFileParser.parseFile(
        fileName: 'test.csv',
        bytes: bytes,
      );

      // BOM stripped from Full Name, and empty intermediate header preserved as Column_2
      expect(table.headers, equals(['Full Name', 'Column_2', 'Phone Number', 'Notes']));
      expect(table.rows.length, equals(2));
      expect(table.emptyRowsSkipped, equals(1));
      expect(table.rows[0][0], equals('Ahmad "Dato" Faiz, bin Razak'));
      expect(table.rows[0][2], equals('012-3456789'));
      expect(table.rows[0][3], contains('near LRT station'));
      // Short row is padded to header length (4)
      expect(table.rows[1].length, equals(4));
      expect(table.rows[1][0], equals('Tan Wei Lun'));
      expect(table.rows[1][2], equals('016-9876543'));
      expect(table.rows[1][3], equals(''));
    });

    test('Parses tab-separated TSV file correctly', () async {
      const tsvContent = "Name\tPhone\tBudget\nAhmad\t0123456789\t650000\nTan\t0169876543\t800000";
      final bytes = Uint8List.fromList(utf8.encode(tsvContent));
      final table = await CRMFileParser.parseFile(
        fileName: 'leads.tsv',
        bytes: bytes,
      );

      expect(table.headers, equals(['Name', 'Phone', 'Budget']));
      expect(table.rows.length, equals(2));
      expect(table.rows[0][0], equals('Ahmad'));
    });
  });

  group('Phase 4.2 & 4.2.1: Data Normalizer & Privacy Scrubbing Tests', () {
    test('Normalizes diverse Malaysian phone number formats to E.164 +601xxxxxxxx', () {
      expect(CRMDataNormalizer.normalizePhone('012-345 6789').canonical, equals('+60123456789'));
      expect(CRMDataNormalizer.normalizePhone('012-345 6789').isValid, isTrue);

      expect(CRMDataNormalizer.normalizePhone('60169876543').canonical, equals('+60169876543'));
      expect(CRMDataNormalizer.normalizePhone('+6019-2233445').canonical, equals('+60192233445'));
      expect(CRMDataNormalizer.normalizePhone('011-12345678').canonical, equals('+601112345678'));
      expect(CRMDataNormalizer.normalizePhone('+60 (0)12-345 6789').canonical, equals('+60123456789'));
      expect(CRMDataNormalizer.normalizePhone('00600123456789').canonical, equals('+60123456789'));
      expect(CRMDataNormalizer.normalizePhone('123456789.0').canonical, equals('+60123456789'));
      expect(CRMDataNormalizer.normalizePhone('03-79567890').canonical, equals('+60379567890'));
      expect(CRMDataNormalizer.normalizePhone('03-79567890').isMobile, isFalse);

      final invalid = CRMDataNormalizer.normalizePhone('12345');
      expect(invalid.isValid, isFalse);
      expect(invalid.canonical, isEmpty);

      final placeholder = CRMDataNormalizer.normalizePhone('N/A');
      expect(placeholder.isValid, isFalse);
      expect(placeholder.canonical, isEmpty);
    });

    test('Normalizes and validates email addresses', () {
      final valid = CRMDataNormalizer.normalizeEmail(' Ahmad.Faiz@Gmail.COM ');
      expect(valid.isValid, isTrue);
      expect(valid.canonical, equals('ahmad.faiz@gmail.com'));

      final invalid = CRMDataNormalizer.normalizeEmail('not-an-email');
      expect(invalid.isValid, isFalse);
      expect(invalid.canonical, isEmpty);
    });

    test('Parses Malaysian Ringgit budget expressions including Million and TO ranges', () {
      final budgetSingle = CRMDataNormalizer.normalizeBudget(singleRaw: 'RM 650,000');
      expect(budgetSingle.isValid, isTrue);
      expect(budgetSingle.min, equals(552500.0));
      expect(budgetSingle.max, equals(747500.0));

      final budgetMillion = CRMDataNormalizer.normalizeBudget(singleRaw: 'RM 1.2 Million');
      expect(budgetMillion.isValid, isTrue);
      expect(budgetMillion.min, equals(1020000.0));
      expect(budgetMillion.max, equals(1380000.0));

      final budgetRangeTo = CRMDataNormalizer.normalizeBudget(minRaw: 'RM 500k to 800k');
      expect(budgetRangeTo.isValid, isTrue);
      expect(budgetRangeTo.min, equals(500000.0));
      expect(budgetRangeTo.max, equals(800000.0));

      final budgetMinMax = CRMDataNormalizer.normalizeBudget(minRaw: '600k', maxRaw: '900k');
      expect(budgetMinMax.isValid, isTrue);
      expect(budgetMinMax.min, equals(600000.0));
      expect(budgetMinMax.max, equals(900000.0));
    });

    test('Infers Malaysian state from prominent locations and scrubs NRIC from notes', () {
      expect(CRMDataNormalizer.inferStateFromLocation('Mont Kiara'), equals('Kuala Lumpur'));
      expect(CRMDataNormalizer.inferStateFromLocation('KLCC'), equals('Kuala Lumpur'));
      expect(CRMDataNormalizer.inferStateFromLocation('Petaling Jaya'), equals('Selangor'));
      expect(CRMDataNormalizer.inferStateFromLocation('Cyberjaya'), equals('Selangor'));
      expect(CRMDataNormalizer.inferStateFromLocation('Bayan Lepas'), equals('Penang'));
      expect(CRMDataNormalizer.inferStateFromLocation('Johor Bahru'), equals('Johor'));
      expect(CRMDataNormalizer.inferStateFromLocation('Kuching'), equals('Sarawak'));
      expect(CRMDataNormalizer.inferStateFromLocation('Kota Kinabalu'), equals('Sabah'));
      expect(CRMDataNormalizer.inferStateFromLocation('Unknown Place', 'Sabah'), equals('Sabah'));

      final scrubbed = CRMDataNormalizer.scrubSensitiveIdentifiers('Buyer IC is 880412-14-5567 for loan check');
      expect(scrubbed, isNot(contains('880412-14-5567')));
      expect(scrubbed, contains('[NRIC-REDACTED]'));
    });
  });

  group('Phase 4.2 & 4.2.1: Column Mapping & Auto-detection Tests', () {
    test('Auto-detects target fields from typical CRM headers', () {
      final headers = [
        'Client Name',
        'Mobile Phone',
        'Email Address',
        'Target Location',
        'State / Region',
        'Budget Min (RM)',
        'Max Price',
        'Property Category',
        'Buying Purpose',
        'Consent Notes',
      ];

      final mapping = ColumnMappingConfig.autoDetect(headers);

      expect(mapping.getHeader(TargetProspectField.fullName), equals('Client Name'));
      expect(mapping.getHeader(TargetProspectField.phone), equals('Mobile Phone'));
      expect(mapping.getHeader(TargetProspectField.email), equals('Email Address'));
      expect(mapping.getHeader(TargetProspectField.preferredLocation), equals('Target Location'));
      expect(mapping.getHeader(TargetProspectField.preferredState), equals('State / Region'));
      expect(mapping.getHeader(TargetProspectField.budgetMin), equals('Budget Min (RM)'));
      expect(mapping.getHeader(TargetProspectField.budgetMax), equals('Max Price'));
      expect(mapping.getHeader(TargetProspectField.propertyType), equals('Property Category'));
      expect(mapping.getHeader(TargetProspectField.purchasePurpose), equals('Buying Purpose'));
      expect(mapping.getHeader(TargetProspectField.consentEvidence), equals('Consent Notes'));
      expect(mapping.hasRequiredFields, isTrue);
    });

    test('Flags missing required field when Full Name is unmapped', () {
      final headers = ['Phone', 'Email', 'Location'];
      final mapping = ColumnMappingConfig.autoDetect(headers);

      expect(mapping.hasRequiredFields, isFalse);
      expect(mapping.missingRequiredLabels, contains('Prospect Full Name'));
    });
  });

  group('Phase 4.2 & 4.2.1: Duplicate Detection & Multi-Tenant Isolation Tests', () {
    const ownerA = 'agent-owner-A';
    const ownerB = 'agent-owner-B';

    final existingProspects = [
      ProspectModel(
        id: 'pros-A1',
        ownerId: ownerA,
        fullName: 'Existing A Prospect',
        phone: '+6012-3456789',
        email: 'prospectA@gmail.com',
        preferredState: 'Kuala Lumpur',
        budgetMin: 500000,
        budgetMax: 700000,
        primarySource: 'CRM Import',
      ),
      ProspectModel(
        id: 'pros-B1',
        ownerId: ownerB,
        fullName: 'Other Agent Prospect',
        phone: '+6017-9999999',
        email: 'otheragent@gmail.com',
        preferredState: 'Selangor',
        budgetMin: 800000,
        budgetMax: 1000000,
        primarySource: 'CRM Import',
      ),
    ];

    final existingBuyers = [
      BuyerModel(
        id: 'buyer-A1',
        name: 'Existing A Buyer',
        email: 'buyerA@yahoo.com',
        phone: '+6016-8888888',
        budgetMin: 600000,
        budgetMax: 900000,
        preferredLocation: 'Mont Kiara',
        preferredState: 'Kuala Lumpur',
        propertyType: 'Condominium',
        purchasePurpose: 'Own Stay',
        buyingTimeline: 'Within 3 months',
        leadSource: 'CRM Import',
        ownerId: ownerA,
        status: 'New',
      ),
    ];

    test('Strict tenant isolation: does NOT match records belonging to other agents', () {
      final detectorA = CRMDuplicateDetector(
        currentOwnerId: ownerA,
        existingProspects: existingProspects,
        existingBuyers: existingBuyers,
      );

      final match = detectorA.checkDuplicate(
        canonicalPhone: '+60179999999',
        canonicalEmail: 'otheragent@gmail.com',
        rowIndex: 1,
      );

      expect(match.isDuplicate, isFalse);
      expect(match.matchedId, isNull);
    });

    test('Matches duplicate across different Malaysian phone formats and email casing for current owner', () {
      final detectorA = CRMDuplicateDetector(
        currentOwnerId: ownerA,
        existingProspects: existingProspects,
        existingBuyers: existingBuyers,
      );

      final phoneMatch = detectorA.checkDuplicate(
        canonicalPhone: '0060 (0)12-345 6789',
        canonicalEmail: 'different@gmail.com',
        rowIndex: 1,
      );
      expect(phoneMatch.isDuplicate, isTrue);
      expect(phoneMatch.matchedField, contains('Phone'));
      expect(phoneMatch.matchedId, equals('pros-A1'));

      final emailMatch = detectorA.checkDuplicate(
        canonicalPhone: '+60191111111',
        canonicalEmail: '  PROSPECTA@GMAIL.COM  ',
        rowIndex: 2,
      );
      expect(emailMatch.isDuplicate, isTrue);
      expect(emailMatch.matchedField, contains('Email'));

      final buyerMatch = detectorA.checkDuplicate(
        canonicalPhone: '016 888 8888',
        canonicalEmail: 'nomatch@gmail.com',
        rowIndex: 3,
      );
      expect(buyerMatch.isDuplicate, isTrue);
      expect(buyerMatch.type, equals(DuplicateType.existingBuyer));
    });

    test('Detects intra-batch duplicates and does NOT falsely flag invalid/placeholder values as duplicates', () {
      final detectorA = CRMDuplicateDetector(
        currentOwnerId: ownerA,
        existingProspects: [],
        existingBuyers: [],
      );

      // Two rows with invalid/placeholder emails ('N/A') and unique valid phones must NOT match as email duplicates
      final row1 = detectorA.checkDuplicate(
        canonicalPhone: '012-1112222',
        canonicalEmail: 'N/A',
        rowIndex: 1,
      );
      expect(row1.isDuplicate, isFalse);

      final row2UniquePhone = detectorA.checkDuplicate(
        canonicalPhone: '012-3334444',
        canonicalEmail: 'N/A',
        rowIndex: 2,
      );
      expect(row2UniquePhone.isDuplicate, isFalse);

      // Row 3 with same phone as Row 1 in different format ('+60121112222') IS an intra-file duplicate
      final row3SamePhone = detectorA.checkDuplicate(
        canonicalPhone: '+60121112222',
        canonicalEmail: 'row3@gmail.com',
        rowIndex: 3,
      );
      expect(row3SamePhone.isDuplicate, isTrue);
      expect(row3SamePhone.type, equals(DuplicateType.intraFileDuplicate));
    });
  });

  group('Phase 4.2 & 4.2.1: Consent Scoping, Purpose/Channel Granularity & Eligibility Audit Tests', () {
    test('Strict default: record without explicit consent defaults to Pending Consent', () {
      final outcome = CRMConsentMapper.evaluateConsent(
        ownerId: 'agent-1',
        prospectId: 'pros-test',
        rawConsentStatus: null,
        rawConsentEvidence: null,
      );

      expect(outcome.contactEligibility, equals('Pending Consent'));
      expect(outcome.consentedPurposes, isEmpty);
      expect(outcome.consentEvent, isNull);
    });

    test('Generic boolean "true", "yes", or "opted in" without documented evidence remains Pending Consent', () {
      final outcome = CRMConsentMapper.evaluateConsent(
        ownerId: 'agent-1',
        prospectId: 'pros-test',
        rawConsentStatus: 'Opted In',
        rawConsentEvidence: 'yes', // Generic token without verifiable proof
      );

      expect(outcome.contactEligibility, equals('Pending Consent'));
      expect(outcome.requiresConsentReview, isTrue);
      expect(outcome.complianceNote, contains('Generic opt-in marker detected without documented proof'));
    });

    test('Direct Inquiry Response consent does NOT automatically authorize broad Marketing & Promotion', () {
      final outcome = CRMConsentMapper.evaluateConsent(
        ownerId: 'agent-1',
        prospectId: 'pros-test',
        rawConsentStatus: 'Opted In',
        rawConsentEvidence: 'WhatsApp inquiry for 3-bedder layout on 12/11/2026',
      );

      expect(outcome.contactEligibility, equals('Eligible'));
      expect(outcome.consentedPurposes, equals(['Direct Inquiry Response']));
      expect(outcome.consentedChannels, equals(['WhatsApp']));
      expect(outcome.permitsBroadMarketing, isFalse);
      expect(outcome.consentEvent, isNotNull);
      expect(outcome.consentEvent!.status, equals('Granted'));
      expect(outcome.consentEvent!.purpose, equals('Direct Inquiry Response'));
      expect(outcome.consentEvent!.communicationChannels, contains('WhatsApp'));
      expect(outcome.consentEvent!.permitsBroadMarketing, isFalse);
      expect(outcome.consentEvent!.permitsDirectInquiryResponse, isTrue);

      final prospect = ProspectModel(
        id: 'pros-test',
        ownerId: 'agent-1',
        fullName: 'Scoped Consent Buyer',
        preferredState: 'Selangor',
        budgetMin: 500000,
        budgetMax: 700000,
        primarySource: 'CRM Import',
        contactEligibility: outcome.contactEligibility,
        consentedPurposes: outcome.consentedPurposes,
        consentedChannels: outcome.consentedChannels,
      );

      // Eligible for direct inquiry response on WhatsApp, but NOT eligible for broad marketing or SMS
      expect(prospect.isEligibleForContact, isTrue);
      expect(prospect.isEligibleForInquiryResponse, isTrue);
      expect(prospect.isEligibleForMarketing, isFalse);
      expect(prospect.canContact(purpose: 'Direct Inquiry Response', channel: 'WhatsApp'), isTrue);
      expect(prospect.canContact(purpose: 'Direct Inquiry Response', channel: 'SMS'), isFalse);
      expect(prospect.canContact(purpose: 'Marketing & Promotion', channel: 'WhatsApp'), isFalse);
    });

    test('Third-Party Sharing consent alone does NOT establish direct buyer contact eligibility', () {
      final outcome = CRMConsentMapper.evaluateConsent(
        ownerId: 'agent-1',
        prospectId: 'pros-tp',
        rawConsentStatus: 'Granted',
        rawConsentEvidence: 'Signed third-party partner sharing disclosure form 2026',
      );

      expect(outcome.contactEligibility, equals('Pending Consent'));
      expect(outcome.requiresConsentReview, isTrue);
    });

    test('Explicit opt-out signal sets Do Not Contact, logs Withdrawn consent event, and blocks all contact', () {
      final outcome = CRMConsentMapper.evaluateConsent(
        ownerId: 'agent-1',
        prospectId: 'pros-test',
        rawConsentStatus: 'Opted Out',
        rawConsentEvidence: 'Requested removal via WhatsApp 05/11/2026',
      );

      expect(outcome.contactEligibility, equals('Do Not Contact'));
      expect(outcome.requiresConsentReview, isFalse);
      expect(outcome.consentEvent, isNotNull);
      expect(outcome.consentEvent!.status, equals('Withdrawn'));
      expect(outcome.consentEvent!.withdrawalTimestamp, isNotNull);
    });
  });

  group('Phase 4.2 & 4.2.1: CRM Import Validator, Verification Separation & Masked Error Report Tests', () {
    test('Validates table, keeps verificationStatus Unverified, and masks all PII in error CSV', () async {
      const csvData =
          'Full Name,Phone Number,Email,Location,Budget Min,Budget Max,Consent Status,Consent Evidence,Notes\n'
          'Ahmad Faiz,012-3456789,ahmad@gmail.com,Mont Kiara,500000,700000,granted,Signed showroom register 10/11/2026,IC 880412-14-5567\n'
          ',016-9876543,missing.name@yahoo.com,Petaling Jaya,400000,600000,,,\n' // Missing name -> error
          'Tan Wei Lun,019-1122334,weilun@gmail.com,Cyberjaya,600000,800000,granted,,\n'; // Generic opt-in without evidence -> warning

      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final table = await CRMFileParser.parseFile(fileName: 'test.csv', bytes: bytes);
      final mapping = ColumnMappingConfig.autoDetect(table.headers);

      final detector = CRMDuplicateDetector(
        currentOwnerId: 'agent-1',
        existingProspects: [],
        existingBuyers: [],
      );

      final report = CRMImportValidator.validateTable(
        table: table,
        mapping: mapping,
        duplicateDetector: detector,
        ownerId: 'agent-1',
        sourceName: 'test.csv',
      );

      expect(report.totalRows, equals(3));
      expect(report.validCount, equals(1)); // Row 1 is fully valid
      expect(report.invalidCount, equals(1)); // Row 2 missing name
      expect(report.warningCount, equals(1)); // Row 3 generic consent warning
      expect(report.hasExecutableRows, isTrue);

      // Verify verificationStatus is strictly 'Unverified' (never conflated with phone regex check)
      final row1Candidate = report.rows.first.candidate!;
      expect(row1Candidate.verificationStatus, equals('Unverified'));
      expect(row1Candidate.isVerified, isFalse);
      expect(row1Candidate.contactEligibility, equals('Eligible'));
      // Verify NRIC was scrubbed from notes
      expect(row1Candidate.notes, isNot(contains('880412-14-5567')));
      expect(row1Candidate.notes, contains('[NRIC-REDACTED]'));

      // Test privacy-masked error report
      final errorCsv = report.generateErrorReportCsv();
      expect(errorCsv, contains('Row Number,Status,Candidate Name,Phone (Masked),Email (Masked),Issues'));
      expect(errorCsv, contains('3,invalid'));
      // Verify raw phone, email, and full name are masked and never leaked in any column
      expect(errorCsv, isNot(contains('016-9876543')));
      expect(errorCsv, isNot(contains('019-1122334')));
      expect(errorCsv, isNot(contains('+60191122334')));
      expect(errorCsv, isNot(contains('missing.name@yahoo.com')));
      expect(errorCsv, isNot(contains('weilun@gmail.com')));
      expect(errorCsv, isNot(contains('Tan Wei Lun')));
      expect(errorCsv, contains('****'));
    });
  });

  group('Phase 4.2 & 4.2.1: Batch Importer Reliability, Idempotent Retries & Consent Precedence Tests', () {
    test('CRMBatchImporter executes batch import, handles merge, preserves Do Not Contact, and is idempotent on retry', () async {
      final repo = InMemoryProspectRepository();
      const ownerId = 'agent-batch-test';

      // Seed 1 existing prospect and 1 Do Not Contact prospect
      final existingProspect = ProspectModel(
        id: 'existing-p1',
        ownerId: ownerId,
        fullName: 'Existing John Doe',
        phone: '+60123456789',
        email: 'john@doe.com',
        preferredState: 'Kuala Lumpur',
        budgetMin: 400000,
        budgetMax: 600000,
        primarySource: 'CRM Import',
        verificationStatus: 'Phone Verified',
      );
      final dncProspect = ProspectModel(
        id: 'existing-dnc',
        ownerId: ownerId,
        fullName: 'Withdrawn DNC Buyer',
        phone: '+60177778888',
        email: 'dnc@buyer.com',
        preferredState: 'Selangor',
        budgetMin: 500000,
        budgetMax: 800000,
        primarySource: 'CRM Import',
        contactEligibility: 'Do Not Contact',
      );
      await repo.createProspect(existingProspect);
      await repo.createProspect(dncProspect);

      const csvData =
          'Full Name,Phone Number,Email,Location,Budget Min,Budget Max,Consent Status,Consent Evidence\n'
          'New Lead Ahmad,016-1122334,ahmad@lead.com,Mont Kiara,500000,700000,Opted In,Signed showroom form 11/11/2026\n'
          'Updated John Doe,012-3456789,john.updated@doe.com,KLCC,600000,900000,,\n'
          'DNC Overwrite Attempt,017-7778888,dnc@buyer.com,PJ,700000,1000000,Opted In,Old form from 2024';

      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final table = await CRMFileParser.parseFile(fileName: 'batch_test.csv', bytes: bytes);
      final mapping = ColumnMappingConfig.autoDetect(table.headers);

      final currentProspects = await repo.getProspects(ownerId: ownerId);
      final detector = CRMDuplicateDetector(
        currentOwnerId: ownerId,
        existingProspects: currentProspects,
        existingBuyers: [],
      );

      final preview = CRMImportValidator.validateTable(
        table: table,
        mapping: mapping,
        duplicateDetector: detector,
        ownerId: ownerId,
        sourceName: 'batch_test.csv',
      );

      final importer = CRMBatchImporter(repository: repo, ownerId: ownerId);

      // 1. First execution with Merge strategy
      final result = await importer.executeImport(
        preview: preview,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        jobId: 'job-merge-test-1',
      );

      expect(result.totalRows, equals(3));
      expect(result.importedCount, equals(1)); // New Lead Ahmad
      expect(result.mergedCount, equals(2)); // Updated John Doe & DNC Buyer
      expect(result.skippedDuplicatesCount, equals(0));
      expect(result.errorCount, equals(0));

      final updatedProspects = await repo.getProspects(ownerId: ownerId);
      expect(updatedProspects.length, equals(3));

      final mergedJohn = updatedProspects.firstWhere((p) => p.id == 'existing-p1');
      expect(mergedJohn.fullName, equals('Updated John Doe'));
      expect(mergedJohn.budgetMax, equals(900000));
      // Preserved existing Phone Verified status
      expect(mergedJohn.verificationStatus, equals('Phone Verified'));

      // Verify Do Not Contact was NEVER overwritten by merge!
      final mergedDnc = updatedProspects.firstWhere((p) => p.id == 'existing-dnc');
      expect(mergedDnc.contactEligibility, equals('Do Not Contact'));
      expect(mergedDnc.isDoNotContact, isTrue);

      // 2. Repeated execution of the exact same jobId -> Idempotent!
      final replayResult = await importer.executeImport(
        preview: preview,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        jobId: 'job-merge-test-1',
      );
      expect(replayResult.jobId, equals('job-merge-test-1'));

      // 3. Retry with a new jobId but the same preview report -> Live deduplication prevents duplicate prospects or duplicate consents!
      final retryNewJobResult = await importer.executeImport(
        preview: preview,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        jobId: 'job-retry-test-2',
      );
      expect(retryNewJobResult.importedCount, equals(0));
      expect(retryNewJobResult.skippedDuplicatesCount, equals(1)); // Row 1 already persisted by deterministic ID
      expect(retryNewJobResult.mergedCount, equals(2)); // Rows 2 and 3 idempotently merged
      final prospectsAfterRetry = await repo.getProspects(ownerId: ownerId);
      expect(prospectsAfterRetry.length, equals(3));

      final ahmadRecord = prospectsAfterRetry.firstWhere((p) => p.fullName == 'New Lead Ahmad');
      final ahmadConsents = await repo.getConsentsForProspect(ahmadRecord.id, ownerId: ownerId);
      // Exactly 1 consent event (never duplicated on retry!)
      expect(ahmadConsents.length, equals(1));
    });
  });

  group('Phase 4.2 & 4.2.1: CRM Import Wizard Dialog UI Flow Widget Tests', () {
    testWidgets('Renders wizard, pastes demo CRM data, transitions through mapping to preview and completion', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppStateProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: CRMImportWizardDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header and Step 1 UI
      expect(find.text('CRM Buyer Enquiry Import Engine'), findsOneWidget);
      expect(find.text('1. File Upload'), findsOneWidget);

      // Switch to Paste Text tab (second ChoiceChip)
      final chips = find.byType(ChoiceChip);
      expect(chips, findsNWidgets(2));
      await tester.tap(chips.last);
      await tester.pumpAndSettle();

      // Tap 'Load Malaysian Demo Leads'
      expect(find.text('Load Malaysian Demo Leads'), findsOneWidget);
      await tester.tap(find.text('Load Malaysian Demo Leads'));
      await tester.pumpAndSettle();

      // Verify file summary card appears
      expect(find.byIcon(Icons.insights), findsOneWidget);
      expect(find.text('Continue to Mapping'), findsOneWidget);

      // Advance to Step 2: Column Mapping
      await tester.tap(find.text('Continue to Mapping'));
      await tester.pumpAndSettle();

      // Verify Step 2 Column Mapping UI
      expect(find.text('2. Column Mapping'), findsOneWidget);
      expect(find.text('Map Source Columns to PropMatch AI Fields'), findsOneWidget);
      expect(find.text('Prospect Full Name'), findsOneWidget);
      expect(find.text('Preview & Validate'), findsOneWidget);

      // Advance to Step 3: Preview & Deduplication
      await tester.tap(find.text('Preview & Validate'));
      await tester.pumpAndSettle();

      // Verify Step 3 Preview UI & KPI cards
      expect(find.text('3. Preview & Deduplication'), findsOneWidget);
      expect(find.text('Duplicate Resolution Strategy'), findsOneWidget);
      expect(find.text('Total Rows'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);

      // Find and tap 'Execute Ingestion' button
      final executeBtn = find.textContaining('Execute Ingestion');
      expect(executeBtn, findsOneWidget);
      await tester.tap(executeBtn);
      await tester.pumpAndSettle();

      // Verify Step 4: Batch Execution Complete
      expect(find.text('Batch Ingestion Complete'), findsOneWidget);
      expect(find.text('Imported'), findsOneWidget);
      expect(find.text('View Prospect Database'), findsOneWidget);
      expect(find.text('Download Audit Report (CSV)'), findsOneWidget);
    });
  });
}
