import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/project_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String _selectedStateFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final nav = context.read<NavigationProvider>();

    final filteredProjects = _selectedStateFilter == 'All'
        ? appState.projects
        : appState.projects.where((p) => p.state == _selectedStateFilter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Property Projects Portfolio',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage development projects, floor plans, and pricing tiers across Malaysia (Penang & Kedah focus).',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              ElevatedButton.icon(
                onPressed: () => _showAddProjectDialog(context, appState),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Project'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Filter bar
          Row(
            children: [
              const Text('Filter by State: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: AppTheme.spacingSm),
              Wrap(
                spacing: 8,
                children: ['All', ...{ 'Penang', 'Kedah', ...appState.projects.map((p) => p.state) }].map((state) {
                  final isSelected = _selectedStateFilter == state;
                  return ChoiceChip(
                    label: Text(state),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedStateFilter = state);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Projects Grid
          if (appState.projects.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXxl, vertical: 60),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.domain_add_outlined,
                      size: 38,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    'No Property Projects Registered Yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      'Add your first developer development or sub-sale listing to unlock AI Audience Discovery, 5-Factor Buyer Matching, and Trilingual Campaign Generation.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProjectDialog(context, appState),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Your First Project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (filteredProjects.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXxl),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.filter_alt_off_outlined, size: 48, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No projects match the selected state filter "$_selectedStateFilter".',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  TextButton(
                    onPressed: () => setState(() => _selectedStateFilter = 'All'),
                    child: const Text('Clear State Filter'),
                  ),
                ],
              ),
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 700
                        ? 2
                        : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppTheme.spacingLg,
                    mainAxisSpacing: AppTheme.spacingLg,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = filteredProjects[index];
                    final isSelected = appState.selectedProject?.id == project.id;
                    return _buildProjectCard(context, project, isSelected, appState, nav);
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    ProjectModel project,
    bool isSelected,
    AppStateProvider appState,
    NavigationProvider nav,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / Image Area
          Container(
            height: 140,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMedium)),
              color: AppTheme.primaryDark,
            ),
            child: Stack(
              children: [
                if (project.imageUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMedium)),
                    child: Image.network(
                      project.imageUrls.first,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        color: AppTheme.primaryDark,
                        child: const Center(
                          child: Icon(Icons.apartment, size: 48, color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent : Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isSelected ? 'ACTIVE PROJECT' : project.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    project.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Details Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${project.location}, ${project.state}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        project.propertyType,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    'RM${project.startingPrice.toStringAsFixed(0)} - RM${project.maximumPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${project.bedrooms} Beds • ${project.bathrooms} Baths • ${project.builtUpArea.toStringAsFixed(0)} sqft',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.description,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  const Divider(height: 16),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () {
                          appState.selectProject(project);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Activated focus on ${project.name}')),
                          );
                        },
                        child: Text(isSelected ? 'Selected' : 'Set Active'),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.people_alt_outlined, size: 18),
                            tooltip: 'Discover Audiences',
                            onPressed: () {
                              appState.selectProject(project);
                              nav.navigateTo(NavItem.audienceDiscovery);
                              appState.runAudienceDiscovery(project);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.compare_arrows, size: 18),
                            tooltip: 'Match Buyers',
                            onPressed: () {
                              appState.selectProject(project);
                              nav.navigateTo(NavItem.matching);
                              appState.runBuyerMatching(project);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                            tooltip: 'Delete Project',
                            onPressed: () => _confirmDeleteProject(context, appState, project),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, AppStateProvider appState, ProjectModel project) {
    final hasActiveLeads = appState.hasActiveLeadsForProject(project.id);
    final hasFollowups = appState.hasFollowupsForProject(project.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property Project', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${project.name}"? This action cannot be undone.'),
            if (hasActiveLeads || hasFollowups) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notice: This project has ${hasActiveLeads ? "active leads" : ""}${(hasActiveLeads && hasFollowups) ? " and " : ""}${hasFollowups ? "pending follow-ups" : ""}.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              appState.deleteProject(project.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${project.name}"')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddProjectDialog(BuildContext context, AppStateProvider appState) {
    final nameCtrl = TextEditingController();
    final devCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final priceMinCtrl = TextEditingController(text: '450000');
    final priceMaxCtrl = TextEditingController(text: '600000');
    final bedsCtrl = TextEditingController(text: '3');
    final bathsCtrl = TextEditingController(text: '2');
    final sqftCtrl = TextEditingController(text: '950');
    final descCtrl = TextEditingController();
    String stateVal = 'Penang';
    String propTypeVal = 'Condominium';
    String purposeVal = 'Own Stay & Investment';
    String? validationError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New Property Project', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (validationError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              validationError!,
                              style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Project Name *', hintText: 'e.g. Vertu Residences'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: devCtrl,
                          decoration: const InputDecoration(labelText: 'Developer *', hintText: 'e.g. Aspen Group'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: stateVal,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'State *'),
                          items: AppConstants.malaysianStates.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setDialogState(() => stateVal = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: locCtrl,
                          decoration: const InputDecoration(labelText: 'Location / Area *', hintText: 'e.g. Batu Kawan'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: propTypeVal,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Property Type *'),
                          items: AppConstants.propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setDialogState(() => propTypeVal = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceMinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Starting Price (RM) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: priceMaxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Price (RM) *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bedsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Bedrooms *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: bathsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Bathrooms *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: sqftCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Built-up (sqft) *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: purposeVal,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Investment or Own Stay *'),
                    items: AppConstants.propertyPurposes.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setDialogState(() => purposeVal = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Project Description', hintText: 'Key highlights, transit connectivity, unique selling propositions...'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final loc = locCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => validationError = 'Project name is required.');
                  return;
                }
                if (loc.isEmpty) {
                  setDialogState(() => validationError = 'Location / Area is required.');
                  return;
                }

                final minPrice = double.tryParse(priceMinCtrl.text);
                final maxPrice = double.tryParse(priceMaxCtrl.text);
                if (minPrice == null || minPrice <= 0) {
                  setDialogState(() => validationError = 'Starting Price must be a positive number.');
                  return;
                }
                if (maxPrice == null || maxPrice <= 0) {
                  setDialogState(() => validationError = 'Maximum Price must be a positive number.');
                  return;
                }
                if (minPrice > maxPrice) {
                  setDialogState(() => validationError = 'Starting Price (RM${minPrice.toStringAsFixed(0)}) cannot exceed Maximum Price (RM${maxPrice.toStringAsFixed(0)}).');
                  return;
                }

                final beds = int.tryParse(bedsCtrl.text);
                final baths = int.tryParse(bathsCtrl.text);
                final sqft = double.tryParse(sqftCtrl.text);
                if (beds == null || beds <= 0) {
                  setDialogState(() => validationError = 'Bedrooms must be at least 1.');
                  return;
                }
                if (baths == null || baths <= 0) {
                  setDialogState(() => validationError = 'Bathrooms must be at least 1.');
                  return;
                }
                if (sqft == null || sqft <= 0) {
                  setDialogState(() => validationError = 'Built-up Area must be greater than 0.');
                  return;
                }

                final newProject = ProjectModel(
                  ownerId: appState.currentOwnerId,
                  name: name,
                  developer: devCtrl.text.trim().isEmpty ? 'Private Developer' : devCtrl.text.trim(),
                  location: loc,
                  state: stateVal,
                  propertyType: propTypeVal,
                  startingPrice: minPrice,
                  maximumPrice: maxPrice,
                  bedrooms: beds,
                  bathrooms: baths,
                  builtUpArea: sqft,
                  purpose: purposeVal,
                  description: descCtrl.text.trim().isEmpty
                      ? 'Modern high-yield property project located in $loc.'
                      : descCtrl.text.trim(),
                );

                appState.addProject(newProject);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added ${newProject.name} to portfolio!')),
                );
              },
              child: const Text('Save Project'),
            ),
          ],
        ),
      ),
    );
  }
}
