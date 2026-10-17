import 'package:flutter/material.dart';

import '../theme/app_layout.dart';
import 'app_card.dart';

/// One scroll surface lets the actions and filters move out of the way of tags.
class QrMobileTagList extends StatelessWidget {
  const QrMobileTagList({
    super.key,
    required this.toolbar,
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.emptyMessage,
  });

  final Widget toolbar;
  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical &&
              notification.metrics.extentAfter < 300 &&
              hasMore &&
              !loading &&
              !loadingMore) {
            onLoadMore();
          }
          return false;
        },
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: toolbar),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(child: AppCard(child: header)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (itemCount == 0)
              SliverToBoxAdapter(
                child: AppCard(child: Center(child: Text(emptyMessage))),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: itemBuilder(context, index),
                    ),
                  ),
                  childCount: itemCount,
                ),
              ),
            if (hasMore && !loading)
              SliverToBoxAdapter(
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: loadingMore ? null : onLoadMore,
                    icon: loadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(loadingMore ? 'Loading…' : 'Load more QR tags'),
                  ),
                ),
              ),
            // AppShell reserves scanner clearance for every mobile screen.
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          ],
        ),
      );
}
