import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/pages/subscription_detail/view.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 订阅列表卡片，对齐 PiliPlusPlus / animeko 风格的竖版海报网格。
class SubItem extends StatelessWidget {
  final SubItemModel item;
  final VoidCallback cancelSub;
  const SubItem({super.key, required this.item, required this.cancelSub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = switch (item.type) {
      11 => '收藏夹',
      21 => '合集',
      _ => '其它',
    };
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        if (item.state == 1) {
          SmartDialog.showToast('该$typeLabel已失效');
          return;
        }
        if (item.type == 11) {
          Get.toNamed('/favDetail', parameters: {
            'mediaId': item.id!.toString(),
          });
        } else {
          SubDetailPage.toSubDetailPage(item.id!, subInfo: item);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: NetworkImgLayer(
                    src: item.cover,
                    width: double.infinity,
                    height: 200,
                  ),
                ),
              ),
              // 类型角标
              Positioned(
                top: 4,
                left: 4,
                child: PBadge(text: typeLabel),
              ),
              // 失效遮罩
              if (item.state == 1)
                Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.black54,
                  child: const Center(
                    child: Text('已失效', style: TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
          // 信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'UP: ${item.upper?.name ?? '?'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${item.mediaCount ?? 0}个视频',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 删除按钮
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: cancelSub,
                tooltip: '取消订阅',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
