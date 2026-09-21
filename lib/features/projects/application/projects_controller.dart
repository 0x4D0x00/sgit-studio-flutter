import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/features/projects/presentation/pages/projects_page.dart';

class ProjectsController extends StateNotifier<List<ProjectItem>> {
  ProjectsController() : super(_initialProjects);

  static final List<ProjectItem> _initialProjects = [
    ProjectItem(
      id: '1',
      name: 'UI',
      description: '',
      updatedAt: DateTime.now().subtract(
        const Duration(
          minutes: 3,
        ),
      ),
    ),
    ProjectItem(
      id: '2',
      name: 'PotAGI',
      description: '水循环的变化速度各不相同。报告对整个水循环过程进行了全面的评估，包括河流流量、地下水、蒸散发、陆地水储量、积雪和冰川，以及高影响事件。这些高影响事件通常指气象领域中的极端灾害。部分环节的变化加快了，比如降水、河流流量和土壤湿度，它们可能在数日或数周内随着天气情况而发生改变。相比之下，地下水、冰川和季节性积雪这类水体变化得比较缓慢，需要经过数个季节、数十年甚至更长的时间才能积累或消耗。',
      updatedAt: DateTime(2025, 11, 4),
    ),
  ];

  void addProject(String name, String description) {
    state = [
      ProjectItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        description: description,
        updatedAt: DateTime.now(),
      ),
      ...state,
    ];
  }

  void updateProject(String id, String name, String description) {
    state = [
      for (final project in state)
        if (project.id == id)
          ProjectItem(
            id: id,
            name: name,
            description: description,
            updatedAt: DateTime.now(),
          )
        else
          project,
    ];
  }

  void deleteProject(String id) {
    state = state.where((p) => p.id != id).toList();
  }
}

final projectsControllerProvider =
    StateNotifierProvider<ProjectsController, List<ProjectItem>>((ref) {
  return ProjectsController();
});
