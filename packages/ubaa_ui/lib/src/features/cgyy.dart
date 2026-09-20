part of '../widgets.dart';

extension _CgyyQueryControls on _FeatureQueryControlsState {
  List<Widget> _cgyyQueryFields(StateSetter setState) => <Widget>[
    if (widget.feature == FeatureId.cgyy) ...<Widget>[
      DropdownButton<FeatureQueryView>(
        value: _cgyyView,
        onChanged: _submitting
            ? null
            : (value) =>
                  setState(() => _cgyyView = value ?? FeatureQueryView.summary),
        items: <DropdownMenuItem<FeatureQueryView>>[
          DropdownMenuItem(
            value: FeatureQueryView.summary,
            child: Text(context.tr('站点列表')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.cgyyPurposeTypes,
            child: Text(context.tr('用途类型')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.cgyyDayInfo,
            child: Text(context.tr('日期空间')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.cgyyOrders,
            child: Text(context.tr('订单列表')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.cgyyOrderDetail,
            child: Text(context.tr('订单详情')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.cgyyLockCode,
            child: Text(context.tr('门锁状态')),
          ),
        ],
      ),
      if (_cgyyView == FeatureQueryView.cgyyDayInfo) ...<Widget>[
        SizedBox(
          width: 110,
          child: TextField(
            controller: _siteController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('站点 ID'),
              hintText: context.tr('从站点列表选择'),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _dateController,
            decoration: InputDecoration(
              labelText: context.tr('日期'),
              hintText: 'YYYY-MM-DD',
              isDense: true,
            ),
          ),
        ),
        _valuePicker(
          label: '从当前站点选择',
          values: _detailFieldValues('站点 ID'),
          onSelected: (value) => _siteController.text = value,
        ),
      ],
      if (_cgyyView == FeatureQueryView.cgyyOrders) ...<Widget>[
        SizedBox(
          width: 110,
          child: TextField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('页码'),
              hintText: context.tr('从 1 开始'),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _sizeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('每页数量'),
              hintText: '1–100',
              isDense: true,
            ),
          ),
        ),
      ],
      if (_cgyyView == FeatureQueryView.cgyyOrderDetail) ...<Widget>[
        SizedBox(
          width: 110,
          child: TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('订单 ID'),
              hintText: context.tr('从订单列表选择'),
              isDense: true,
            ),
          ),
        ),
        _valuePicker(
          label: '从当前订单选择',
          values: _detailFieldValues('订单编号'),
          onSelected: (value) => _orderController.text = value,
        ),
      ],
    ],
  ];
}

extension _CgyyDetailActions on _FeatureDetailListState {
  List<Widget> _cgyyCancelWriteFields(CgyyCancelAction? cgyyCancelAction) =>
      <Widget>[
        if (cgyyCancelAction != null &&
            widget.onCgyyCancelWrite != null) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => widget.onCgyyCancelWrite!(cgyyCancelAction),
            icon: const Icon(Icons.event_busy),
            label: Text(context.tr('准备取消订单')),
          ),
        ],
      ];

  List<Widget> _cgyyReserveWriteFields(
    BuildContext context,
    CgyyReserveAction? cgyyReservation,
  ) => <Widget>[
    if (cgyyReservation != null &&
        widget.onCgyySubmitWrite != null) ...<Widget>[
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _showCgyyReservationForm(
          context,
          cgyyReservation,
          _cgyyReserveCandidates(cgyyReservation),
        ),
        icon: const Icon(Icons.event_available),
        label: Text(context.tr('准备研讨室预约')),
      ),
    ],
  ];

  CgyyCancelAction? _cgyyCancelAction(FeatureDetail detail) {
    if (widget.feature != FeatureId.cgyy) return null;
    final action = detail.action<CgyyCancelAction>();
    return action?.hasCanonicalTarget == true ? action : null;
  }

  CgyyReserveAction? _cgyyReserveAction(FeatureDetail detail) {
    if (widget.feature != FeatureId.cgyy) return null;
    final action = detail.action<CgyyReserveAction>();
    return action != null && _isUsableCgyyReserveAction(action) ? action : null;
  }

  bool _isUsableCgyyReserveAction(CgyyReserveAction action) =>
      action.eligibility == ActionEligibility.allowed &&
      action.venueSiteId > 0 &&
      action.reservationDate.trim().isNotEmpty &&
      action.spaceId > 0 &&
      action.timeId > 0 &&
      action.timeOrdinal >= 0 &&
      (action.venueSpaceGroupId == null || action.venueSpaceGroupId! > 0);

  List<CgyyReserveAction> _cgyyReserveCandidates(CgyyReserveAction target) {
    final seen = <String>{};
    final candidates = <CgyyReserveAction>[];
    for (final detail in widget.details) {
      final candidate = _cgyyReserveAction(detail);
      if (candidate == null ||
          candidate.venueSiteId != target.venueSiteId ||
          candidate.reservationDate.trim() != target.reservationDate.trim() ||
          candidate.spaceId != target.spaceId ||
          candidate.venueSpaceGroupId != target.venueSpaceGroupId) {
        continue;
      }
      if (seen.add(_cgyyActionKey(candidate))) candidates.add(candidate);
    }
    candidates.sort(
      (left, right) => left.timeOrdinal.compareTo(right.timeOrdinal),
    );
    return List<CgyyReserveAction>.unmodifiable(candidates);
  }
}
