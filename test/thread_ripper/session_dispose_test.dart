import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/media_transport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scheduler_test.dart';

void main() {
  test('serve after dispose returns null', () {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);

    session.dispose();
    final response = session.serve(
      descriptor(total: 1000),
      const RangeRequest(first: 0),
    );
    expect(response, isNull);
    expect(transport.openCalls, 0);
  });

  test('dispose terminates an in-flight response stream', () async {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);

    final response = session.serve(
      descriptor(total: 1000),
      const RangeRequest(first: 0),
    );
    expect(response, isNotNull);
    final errors = <Object>[];
    var done = false;
    response!.stream.listen(
      (_) {},
      onError: errors.add,
      onDone: () => done = true,
    );
    await settle();

    // One upstream connection has been opened; let headers through so the
    // attempt is running, then tear the whole session down.
    expect(transport.openCalls, greaterThan(0));
    transport.requests.first.respond(contentRange: 'bytes 0-999/1000');
    await settle();

    session.dispose();
    for (var i = 0; i < 50 && !done && errors.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      done || errors.isNotEmpty,
      isTrue,
      reason: 'the in-flight response must terminate after dispose',
    );
    // Subsequent serves are refused.
    expect(
      session.serve(descriptor(total: 1000), const RangeRequest(first: 0)),
      isNull,
    );
  });
}
