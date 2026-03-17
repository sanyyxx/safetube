sealed class Resource<T> {
  const Resource();
}

final class ResourceLoading<T> extends Resource<T> {
  const ResourceLoading();
}

final class ResourceSuccess<T> extends Resource<T> {
  const ResourceSuccess(this.data);
  final T data;
}

final class ResourceError<T> extends Resource<T> {
  const ResourceError(this.message);
  final String message;
}

