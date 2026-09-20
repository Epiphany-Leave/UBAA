part of '../widgets.dart';

extension _FeatureDetailPagination on _FeatureDetailListState {
  List<Widget> _paginationFields(
    StateSetter setState,
    FeaturePagination? serverPagination,
    int pageCount,
    int page,
  ) => <Widget>[
    if (serverPagination != null &&
        widget.onQuery != null &&
        widget.query != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              tooltip: context.tr('上一页'),
              onPressed: serverPagination.page <= 1
                  ? null
                  : () => widget.onQuery!(
                      widget.query!.copyWith(page: serverPagination.page - 1),
                    ),
              icon: const Icon(Icons.chevron_left),
            ),
            Semantics(
              label: context.tr('服务端分页'),
              child: Text(
                serverPagination.effectiveTotalPages > 0
                    ? context.tr("第 {0} / {1} 页（共 {2} 条）", [
                        serverPagination.page,
                        serverPagination.effectiveTotalPages,
                        serverPagination.total,
                      ])
                    : context.tr("第 {0} 页（共 {1} 条）", [
                        serverPagination.page,
                        serverPagination.total,
                      ]),
              ),
            ),
            IconButton(
              tooltip: context.tr('下一页'),
              onPressed:
                  !(serverPagination.hasMore ??
                      (serverPagination.effectiveTotalPages > 0 &&
                          serverPagination.page <
                              serverPagination.effectiveTotalPages))
                  ? null
                  : () => widget.onQuery!(
                      widget.query!.copyWith(page: serverPagination.page + 1),
                    ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      )
    else if (pageCount > 1)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              tooltip: context.tr('上一页'),
              onPressed: page == 0
                  ? null
                  : () => setState(() => _page = page - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Semantics(
              label: context.tr('详情分页'),
              child: Text('${page + 1} / $pageCount'),
            ),
            IconButton(
              tooltip: context.tr('下一页'),
              onPressed: page + 1 >= pageCount
                  ? null
                  : () => setState(() => _page = page + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
  ];
}
