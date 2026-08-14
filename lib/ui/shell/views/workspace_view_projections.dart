import 'package:flutter/foundation.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// Stable shell projection used to isolate the top bar from protocol events.
class WorkspaceTopBarProjection {
  const WorkspaceTopBarProjection({
    required this.section,
    required this.requestView,
    required this.environmentIds,
    required this.environmentNames,
    required this.activeEnvironmentId,
    required this.hasEnvironmentChanges,
    required this.noticeCount,
  });

  factory WorkspaceTopBarProjection.fromViewModel(
    WorkspaceViewModel viewModel,
  ) {
    final environments = viewModel.environments;
    return WorkspaceTopBarProjection(
      section: viewModel.activeSection,
      requestView: viewModel.requestWorkingView,
      environmentIds: environments
          .map((environment) => environment.id)
          .toList(growable: false),
      environmentNames: environments
          .map((environment) => environment.name)
          .toList(growable: false),
      activeEnvironmentId: viewModel.activeEnvironment.id,
      hasEnvironmentChanges: viewModel.hasEnvironmentChanges,
      noticeCount: viewModel.notices.length,
    );
  }

  final WorkspaceSection section;
  final RequestWorkingView requestView;
  final List<String> environmentIds;
  final List<String> environmentNames;
  final String activeEnvironmentId;
  final bool hasEnvironmentChanges;
  final int noticeCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceTopBarProjection &&
          section == other.section &&
          requestView == other.requestView &&
          listEquals(environmentIds, other.environmentIds) &&
          listEquals(environmentNames, other.environmentNames) &&
          activeEnvironmentId == other.activeEnvironmentId &&
          hasEnvironmentChanges == other.hasEnvironmentChanges &&
          noticeCount == other.noticeCount;

  @override
  int get hashCode => Object.hash(
    section,
    requestView,
    Object.hashAll(environmentIds),
    Object.hashAll(environmentNames),
    activeEnvironmentId,
    hasEnvironmentChanges,
    noticeCount,
  );
}
