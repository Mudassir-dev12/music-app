/// A simple Result type with [Ok] and [Err] variants.
///
/// Usage:
/// ```dart
/// Result<String> parse(String input) {
///   if (input.isEmpty) return const Err('empty input');
///   return Ok(input.trim());
/// }
///
/// switch (parse(raw)) {
///   case Ok(:final value) => print(value);
///   case Err(:final error) => print('Error: $error');
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Whether this result is [Ok].
  bool get isOk => this is Ok<T>;

  /// Whether this result is [Err].
  bool get isErr => this is Err<T>;

  /// Returns the value if [Ok], or throws if [Err].
  T get value {
    final self = this;
    if (self is Ok<T>) return self.value;
    throw StateError('Called Result.value on an Err: ${(self as Err<T>).error}');
  }

  /// Returns the error if [Err], or throws if [Ok].
  Object get error {
    final self = this;
    if (self is Err<T>) return self.error;
    throw StateError('Called Result.error on an Ok');
  }

  /// Maps the value with [f] if [Ok]; otherwise propagates the [Err].
  Result<R> map<R>(R Function(T value) f) {
    final self = this;
    return switch (self) {
      Ok<T>(:final value) => Ok<R>(f(value)),
      Err<T>(:final error) => Err<R>(error),
    };
  }

  /// Maps the error if [Err]; otherwise propagates [Ok] unchanged.
  Result<T> mapErr(Object Function(Object error) f) {
    final self = this;
    return switch (self) {
      Ok<T>() => self,
      Err<T>(:final error) => Err<T>(f(error)),
    };
  }

  /// Returns [defaultValue] when [Err].
  T getOrElse(T defaultValue) {
    final self = this;
    return self is Ok<T> ? self.value : defaultValue;
  }
}

/// Successful result containing [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  @override
  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// Failed result containing [error].
final class Err<T> extends Result<T> {
  const Err(this.error);

  @override
  final Object error;

  @override
  String toString() => 'Err($error)';
}
