import 'package:material_ui/material_ui.dart';

enum LoadingState<T> { loading, success(T), error(String) }

class HttpError {
  final String message;
  const HttpError(this.message);
}
