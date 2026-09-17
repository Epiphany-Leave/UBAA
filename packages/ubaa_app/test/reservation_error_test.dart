import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_app/src/contracts/backend.dart';
import 'package:ubaa_app/src/controller/error_mapper.dart';
import 'package:ubaa_domain/ubaa_domain.dart';

void main() {
  test('预约固定原因在协调器重新包装后保留，任意上游正文不展示', () {
    const message = '课程选课资格缺少必要字段';
    final error = UbaaErrorMapper.fromException(
      const BackendException(UbaaErrorCode.upstreamChanged, detail: message),
    );
    expect(error.message, message);
    expect(
      UbaaErrorMapper.fromException(BackendException.fromUi(error)).message,
      message,
    );
    final unknown = UbaaErrorMapper.fromException(
      const BackendException(
        UbaaErrorCode.upstreamChanged,
        detail: 'private token=fixture',
      ),
    );
    expect(unknown.message, isNot(contains('fixture')));
  });
}
