import 'package:flutter/material.dart';

/// Animated message bubble that slides in from side and fades
class AnimatedMessageBubble extends StatefulWidget {
  final String message;
  final bool isFromMe;
  final String? senderName;
  final DateTime timestamp;
  final bool isLoading;
  final Color? bubbleColor;
  final TextStyle? textStyle;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.isFromMe,
    this.senderName,
    required this.timestamp,
    this.isLoading = false,
    this.bubbleColor,
    this.textStyle,
  });

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Slide from right or left depending on sender
    _slideAnimation = Tween<Offset>(
      begin: widget.isFromMe ? const Offset(1, 0) : const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Fade in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildMessageBubble(),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: widget.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: widget.isFromMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!widget.isFromMe && widget.senderName != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  widget.senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: widget.bubbleColor ??
                    (widget.isFromMe
                        ? Colors.blue
                        : (isDarkMode ? Colors.grey[800] : Colors.grey[200])),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(widget.isFromMe ? 16 : 4),
                  bottomRight: Radius.circular(widget.isFromMe ? 4 : 16),
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message,
                      style: widget.textStyle ??
                          TextStyle(
                            color:
                                widget.isFromMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                    ),
                    if (widget.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isFromMe ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Text(
                _formatTime(widget.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// List of animated message bubbles with staggered animation
class AnimatedMessageList extends StatelessWidget {
  final List<MessageData> messages;
  final ScrollController? scrollController;

  const AnimatedMessageList({
    super.key,
    required this.messages,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: messages.length,
      reverse: true, // Show newest at bottom
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return AnimatedMessageBubble(
          message: message.content,
          isFromMe: message.isFromMe,
          senderName: message.senderName,
          timestamp: message.timestamp,
          isLoading: message.isLoading,
          bubbleColor: message.bubbleColor,
          textStyle: message.textStyle,
        );
      },
    );
  }
}

/// Data model for messages
class MessageData {
  final String content;
  final bool isFromMe;
  final String? senderName;
  final DateTime timestamp;
  final bool isLoading;
  final Color? bubbleColor;
  final TextStyle? textStyle;

  MessageData({
    required this.content,
    required this.isFromMe,
    this.senderName,
    required this.timestamp,
    this.isLoading = false,
    this.bubbleColor,
    this.textStyle,
  });
}

/// Typing indicator animation
class TypingIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const TypingIndicator({
    super.key,
    this.color = Colors.grey,
    this.size = 10,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress =
                  ((_controller.value * 3 - index) % 1.0).clamp(0.0, 1.0);
              final height = widget.size +
                  (8 * (0.5 + 0.5 * Curves.easeInOut.transform(progress)));

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: height,
                  width: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
