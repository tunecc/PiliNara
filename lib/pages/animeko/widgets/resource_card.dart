/// Resource card widget for displaying anime download links.

import 'package:PiliNara/models_new/animeko/animeko_resource.dart';
import 'package:PiliNara/utils/page_utils.dart';
import 'package:PiliNara/utils/utils.dart';
import 'package:flutter/material.dart' as material;
import 'package:material_ui/material_ui.dart';

class ResourceCard extends StatelessWidget {
  final AnimekoResource resource;

  const ResourceCard({super.key, required this.resource});

  void _copyLink() {
    Utils.copyText(resource.downloadUrl);
  }

  void _openLink() {
    PageUtils.launchURL(resource.downloadUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTorrent = resource.isTorrent;

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: isTorrent ? null : _openLink,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: resource.sourceId == 'mikan'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  resource.sourceId == 'mikan' ? '蜜柑' : 'DMHY',
                  style: TextStyle(
                    fontSize: 12,
                    color: resource.sourceId == 'mikan' ? Colors.green : Colors.blue,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      resource.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Meta info
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (resource.episode != null)
                          Chip(
                            label: Text('第${resource.episode}集'),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (resource.resolution.isNotEmpty)
                          Chip(
                            label: Text(resource.resolution),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (resource.alliance.isNotEmpty)
                          Chip(
                            label: Text(resource.alliance),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (resource.sizeBytes > 0)
                          Chip(
                            label: Text(resource.sizeString),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTorrent)
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: '打开链接',
                      onPressed: _openLink,
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制链接',
                    onPressed: _copyLink,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
