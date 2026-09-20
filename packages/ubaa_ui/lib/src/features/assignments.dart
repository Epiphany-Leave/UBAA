part of '../widgets.dart';

extension _AssignmentsQueryControls on _FeatureQueryControlsState {
  List<Widget> _spocQueryFields(StateSetter setState) => <Widget>[
    if (widget.feature == FeatureId.spoc) ...<Widget>[
      DropdownButton<FeatureQueryView>(
        value: _spocView,
        onChanged: _submitting
            ? null
            : (value) =>
                  setState(() => _spocView = value ?? FeatureQueryView.summary),
        items: <DropdownMenuItem<FeatureQueryView>>[
          DropdownMenuItem(
            value: FeatureQueryView.summary,
            child: Text(context.tr('作业列表')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.spocDetail,
            child: Text(context.tr('作业详情')),
          ),
        ],
      ),
      if (_spocView == FeatureQueryView.spocDetail) ...<Widget>[
        SizedBox(
          width: 160,
          child: TextField(
            controller: _spocAssignmentController,
            decoration: InputDecoration(
              labelText: context.tr('作业编号'),
              hintText: context.tr('从作业列表选择'),
              isDense: true,
            ),
          ),
        ),
        _valuePicker(
          label: '从当前作业列表选择',
          values: _detailFieldValues('作业编号'),
          onSelected: (value) => _spocAssignmentController.text = value,
        ),
      ],
    ],
  ];

  List<Widget> _signinQueryFields(StateSetter setState) => <Widget>[
    if (widget.feature == FeatureId.signin)
      DropdownButton<FeatureQueryView>(
        value: _signinView,
        onChanged: _submitting
            ? null
            : (value) => setState(
                () => _signinView = value ?? FeatureQueryView.summary,
              ),
        items: <DropdownMenuItem<FeatureQueryView>>[
          DropdownMenuItem(
            value: FeatureQueryView.summary,
            child: Text(context.tr('全部课程')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.signinPending,
            child: Text(context.tr('未签到')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.signinCompleted,
            child: Text(context.tr('已签到')),
          ),
        ],
      ),
  ];

  List<Widget> _judgeQueryFields(StateSetter setState) => <Widget>[
    if (widget.feature == FeatureId.judge) ...<Widget>[
      DropdownButton<FeatureQueryView>(
        value: _judgeView,
        onChanged: _submitting
            ? null
            : (value) => setState(
                () => _judgeView = value ?? FeatureQueryView.summary,
              ),
        items: <DropdownMenuItem<FeatureQueryView>>[
          DropdownMenuItem(
            value: FeatureQueryView.summary,
            child: Text(context.tr('作业列表')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.judgeDetail,
            child: Text(context.tr('作业详情')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.judgeBatchDetails,
            child: Text(context.tr('批量详情')),
          ),
        ],
      ),
      if (_judgeView == FeatureQueryView.judgeDetail) ...<Widget>[
        SizedBox(
          width: 140,
          child: TextField(
            controller: _judgeCourseController,
            decoration: InputDecoration(
              labelText: context.tr('课程编号'),
              hintText: context.tr('从作业列表选择'),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: _judgeAssignmentController,
            decoration: InputDecoration(
              labelText: context.tr('作业编号'),
              hintText: context.tr('从作业列表选择'),
              isDense: true,
            ),
          ),
        ),
        _valuePicker(
          label: '从当前作业列表选择课程',
          values: _detailFieldValues('课程编号'),
          onSelected: (value) => _judgeCourseController.text = value,
        ),
        _valuePicker(
          label: '从当前作业列表选择作业',
          values: _detailFieldValues('作业编号'),
          onSelected: (value) => _judgeAssignmentController.text = value,
        ),
      ],
      if (_judgeView == FeatureQueryView.judgeBatchDetails)
        SizedBox(
          width: 320,
          child: TextField(
            controller: _judgeBatchController,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.tr('批量作业键'),
              hintText: context.tr('每行：课程编号/作业编号'),
              helperText: context.tr('仅填写作业列表中的公开编号'),
              isDense: true,
            ),
          ),
        ),
      if (_judgeView == FeatureQueryView.summary)
        FilterChip(
          label: Text(context.tr('包含已过期作业')),
          selected: _includeExpired,
          onSelected: _submitting
              ? null
              : (selected) => setState(() => _includeExpired = selected),
        ),
    ],
  ];
}

extension _AssignmentsDetailActions on _FeatureDetailListState {
  List<Widget> _signinWriteFields(
    BuildContext context,
    SigninPerformAction? signinAction,
    bool canSignin,
  ) => <Widget>[
    if (widget.feature == FeatureId.signin &&
        widget.onSigninWrite != null &&
        signinAction != null) ...<Widget>[
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: canSignin ? () => widget.onSigninWrite!(signinAction) : null,
        icon: const Icon(Icons.how_to_reg),
        label: Text(context.tr('准备签到')),
      ),
      if (!canSignin)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            signinAction.eligibility == ActionEligibility.denied
                ? context.tr('该课程已签到，不能重复提交。')
                : context.tr('当前签到资格无法确认，请刷新后重试。'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  ];
}
