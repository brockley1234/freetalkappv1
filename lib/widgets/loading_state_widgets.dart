import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';
import '../utils/app_logger.dart';

/// Reusable async loading state wrapper
/// Displays loading, error, or content based on AsyncSnapshot state
class AsyncStateBuilder<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;
  final Widget Function(BuildContext, T) builder;
  final Widget Function(BuildContext)? onLoading;
  final Widget Function(BuildContext, Object?)? onError;
  final String? loadingMessage;
  final String? errorMessage;

  const AsyncStateBuilder({
    super.key,
    required this.snapshot,
    required this.builder,
    this.onLoading,
    this.onError,
    this.loadingMessage,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return onLoading?.call(context) ??
          _buildLoadingState(context, loadingMessage);
    }

    if (snapshot.hasError) {
      AppLogger().error('AsyncStateBuilder error: ${snapshot.error}',
          error: snapshot.error, stackTrace: snapshot.stackTrace);
      return onError?.call(context, snapshot.error) ??
          _buildErrorState(context, snapshot.error, errorMessage);
    }

    if (!snapshot.hasData) {
      return _buildEmptyState(context);
    }

    return builder(context, snapshot.data as T);
  }

  /// Default loading state with circular progress indicator
  Widget _buildLoadingState(BuildContext context, String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: ResponsiveUtils.getMargin(context)),
            Text(
              message,
              style: TextStyle(
                fontSize: ResponsiveUtils.getBodySize(context),
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Default error state with retry option
  Widget _buildErrorState(
      BuildContext context, Object? error, String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: ResponsiveUtils.getLargeIconSize(context),
            color: Colors.red,
          ),
          SizedBox(height: ResponsiveUtils.getMargin(context)),
          Text(
            message ?? 'Something went wrong',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ResponsiveUtils.getBodySize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (error != null) ...[
            SizedBox(height: ResponsiveUtils.getSmallSpacing(context)),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveUtils.getSmallSize(context),
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Empty state when data is null
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: ResponsiveUtils.getLargeIconSize(context),
            color: Colors.grey,
          ),
          SizedBox(height: ResponsiveUtils.getMargin(context)),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: ResponsiveUtils.getBodySize(context),
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linear progress indicator for file uploads
/// Shows progress percentage and file size
class UploadProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final int? totalBytes;
  final int uploadedBytes;
  final String? fileName;

  const UploadProgressIndicator({
    super.key,
    required this.progress,
    this.totalBytes,
    required this.uploadedBytes,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final percentText = '${(progress * 100).toStringAsFixed(0)}%';
    final sizeText = _formatBytes(uploadedBytes, totalBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                fileName ?? 'Uploading...',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getSmallSize(context),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$percentText • $sizeText',
              style: TextStyle(
                fontSize: ResponsiveUtils.getSmallSize(context),
                color: Colors.grey,
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getSmallSpacing(context)),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: ResponsiveUtils.getSmallSpacing(context) * 2,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Format bytes to readable size (e.g., "2.5 MB of 10 MB")
  String _formatBytes(int uploaded, int? total) {
    if (total == null) {
      return _toReadableSize(uploaded);
    }
    return '${_toReadableSize(uploaded)} / ${_toReadableSize(total)}';
  }

  String _toReadableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Shimmer loading effect for list items
class ShimmerLoadingPlaceholder extends StatelessWidget {
  final int itemCount;
  final bool isLoading;
  final Widget child;

  const ShimmerLoadingPlaceholder({
    super.key,
    this.itemCount = 3,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getPadding(context)),
          child: _buildShimmerItem(context),
        );
      },
    );
  }

  Widget _buildShimmerItem(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getBorderRadius(context),
        ),
      ),
      height: ResponsiveUtils.getListItemHeight(context),
    );
  }
}

/// Circular progress indicator with percentage text
class PercentageProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final String? label;
  final double size;

  const PercentageProgressIndicator({
    super.key,
    required this.progress,
    this.label,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toStringAsFixed(0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getBodySize(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (label != null) ...[
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getSmallSize(context),
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Network status indicator
/// Shows if device is online or offline
class NetworkStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final String onlineLabel;
  final String offlineLabel;

  const NetworkStatusIndicator({
    super.key,
    required this.isOnline,
    this.onlineLabel = 'Online',
    this.offlineLabel = 'Offline',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getPadding(context),
        vertical: ResponsiveUtils.getSmallSpacing(context),
      ),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getSmallBorderRadius(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ResponsiveUtils.getSmallSpacing(context)),
          Text(
            isOnline ? onlineLabel : offlineLabel,
            style: TextStyle(
              fontSize: ResponsiveUtils.getSmallSize(context),
              fontWeight: FontWeight.w500,
              color: isOnline ? Colors.green[900] : Colors.red[900],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen loading overlay
/// Prevents user interaction while loading
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final double opacity;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.opacity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // Prevent interaction
              child: Container(
                color: Colors.black.withValues(alpha: opacity),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                      if (message != null) ...[
                        SizedBox(height: ResponsiveUtils.getMargin(context)),
                        Text(
                          message!,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getBodySize(context),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Retry button for failed operations
class RetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  final String label;
  final bool isLoading;

  const RetryButton({
    super.key,
    required this.onRetry,
    this.label = 'Retry',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onRetry,
      icon: isLoading
          ? SizedBox(
              width: ResponsiveUtils.getSmallIconSize(context),
              height: ResponsiveUtils.getSmallIconSize(context),
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getPadding(context),
          vertical: ResponsiveUtils.getSmallSpacing(context),
        ),
      ),
    );
  }
}
