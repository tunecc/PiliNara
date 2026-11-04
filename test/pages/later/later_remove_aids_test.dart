import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/later/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('拼接移除参数时跳过没有 aid 的条目', () {
    expect(
      laterRemoveAids({
        LaterItemModel(aid: 1),
        LaterItemModel(),
        LaterItemModel(aid: 2),
      }),
      '1,2',
    );
  });

  test('全部没有 aid 时返回空串，调用方据此不发请求', () {
    expect(laterRemoveAids({LaterItemModel()}), isEmpty);
    expect(laterRemoveAids(const <LaterItemModel>{}), isEmpty);
  });
}
