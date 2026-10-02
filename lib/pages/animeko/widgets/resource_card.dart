/// 资源卡片
import 'package:PiliPlus/models_new/animeko/animeko_resource.dart';
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart';

class ResourceCard extends StatelessWidget {
  final AnimekoResource resource;

  const ResourceCard({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: resource.source == 'mikan' ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                resource.source == 'mikan' ? '蜜柑' : 'DMHY',
                style: TextStyle(fontSize: 12, color: resource.source == 'mikan' ? Colors.green : Colors.blue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: [
                      if (resource.resolution != null) Chip(label: Text(resource.resolution!), visualDensity: VisualDensity.compact),
                      if (resource.alliance.isNotEmpty) Chip(label: Text(resource.alliance), visualDensity: VisualDensity.compact),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.copy), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
