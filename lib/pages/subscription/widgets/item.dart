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

/// 订阅列表卡片，对齐 PiliPlusPlus 横版行卡片风格。
class SubItem extends StatelessWidget {
  final SubItemModel item;
  final VoidCallback cancelSub;
  const SubItem({super.key, required this.item, required this.cancelSub});

  @override
  Widget build(BuildContext context) {
    String heroTag = Utils.makeHeroTag(item.id);
    final type = switch (item.type) {
      11 => '收藏夹',
      21 => '合集',
      _ => '其它(${item.type})',
    };
    void onLongPress() => imageSaveDialog(
      title: item.title,
      cover: item.cover,
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          if (item.state == 1) {
            SmartDialog.showToast('该$type已失效');
            return;
          }
          if (item.type == 11) {
            Get.toNamed(
              '/favDetail',
              parameters: {
                'mediaId': item.id!.toString(),
                'heroTag': heroTag,
              },
            );
          } else {
            SubDetailPage.toSubDetailPage(
              item.id!,
              heroTag: heroTag,
              subInfo: item,
            );
          }
        },
        onLongPress: onLongPress,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面 (16:9)
              AspectRatio(
                aspectRatio: Style.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, boxConstraints) {
                    double maxWidth = boxConstraints.maxWidth;
                    double maxHeight = boxConstraints.maxHeight;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Hero(
                          tag: heroTag,
                          child: NetworkImgLayer(
                            src: item.cover,
                            width: maxWidth,
                            height: maxHeight,
                          ),
                        ),
                        PBadge(
                          right: 6,
                          top: 6,
                          text: type,
                        ),
                        if (item.state == 1)
                          Container(
                            color: Colors.black54,
                            width: maxWidth,
                            height: maxHeight,
                            child: const Center(
                              child: Text('已失效',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              _content(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final style = TextStyle(
      fontSize: 13,
      color: theme.colorScheme.outline,
    );
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: const TextStyle(letterSpacing: 0.3),
                ),
              ),
              Text(
                'UP主: ${item.upper?.name ?? '?'}',
                textAlign: TextAlign.start,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${item.mediaCount ?? 0}个视频',
                textAlign: TextAlign.start,
                style: style,
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            right: 0,
            height: 35,
            width: 35,
            child: IconButton(
              onPressed: cancelSub,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.outline,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
