import 'package:flutter/material.dart';

/// A robust FutureBuilder that handles loading, error, and success states properly
class RobustFutureBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Function(Object error, StackTrace stackTrace)? onError;

  const RobustFutureBuilder({
    Key? key,
    required this.future,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.onError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Log the error
          if (onError != null) {
            onError!(snapshot.error!, snapshot.stackTrace!);
          } else {
            // Default error logging
            debugPrint(
              'FutureBuilder error: ${snapshot.error}\n${snapshot.stackTrace}',
            );
          }

          return errorWidget ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Rebuild the widget to retry the future
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
        }

        if (snapshot.hasData) {
          return builder(context, snapshot.data as T);
        }

        // Handle the case where there's no data and no error
        return errorWidget ?? const Center(child: Text('No data available'));
      },
    );
  }
}

/// A robust StreamBuilder that handles loading, error, and success states properly
class RobustStreamBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final Function(Object error, StackTrace stackTrace)? onError;

  const RobustStreamBuilder({
    Key? key,
    required this.stream,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.onError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Log the error
          if (onError != null) {
            onError!(snapshot.error!, snapshot.stackTrace!);
          } else {
            // Default error logging
            debugPrint(
              'StreamBuilder error: ${snapshot.error}\n${snapshot.stackTrace}',
            );
          }

          return errorWidget ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Rebuild the widget to retry (if applicable)
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
        }

        if (snapshot.hasData) {
          return builder(context, snapshot.data as T);
        }

        // Handle the case where there's no data and no error
        return emptyWidget ?? const Center(child: Text('No data available'));
      },
    );
  }
}
