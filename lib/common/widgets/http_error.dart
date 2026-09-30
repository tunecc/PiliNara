import 'package:flutter/material.dart';

enum LoadingState<T> { loading, success(T), error(String) }

class HttpError {
  final String message;
  const HttpError(this.message);
}
