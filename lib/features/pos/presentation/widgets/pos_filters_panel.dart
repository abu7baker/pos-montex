import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/database/app_db.dart';
import '../../../../core/database/db_provider.dart';
import 'customer_add_dialog.dart';
import 'pos_select.dart';

class PosFiltersPanel extends ConsumerStatefulWidget {
  const PosFiltersPanel({
    super.key,
    this.compact = false,
    this.showServices = true,
    this.showTables = true,
    this.onCustomerChanged,
    this.onServiceChanged,
    this.onTableChanged,
  });

  final bool compact;
  final bool showServices;
  final bool showTables;
  final void Function(int? customerId, String customerName)? onCustomerChanged;
  final void Function(int? serviceId, String serviceName, double serviceCost)?
  onServiceChanged;
  final void Function(int? tableId, String tableName)? onTableChanged;

  @override
  ConsumerState<PosFiltersPanel> createState() => _PosFiltersPanelState();
}

class _PosFiltersPanelState extends ConsumerState<PosFiltersPanel> {
  static const _walkInCustomerValue = 'walkin';
  static const _walkInCustomerLabel = 'عميل عام';

  String? _selectedService;
  String? _selectedTable;
  String? _selectedCustomer;

  String _customerDisplayName(CustomerDb customer) {
    final name = customer.name.trim();
    if (name.isNotEmpty) return name;
    return 'عميل #${customer.id}';
  }

  String? _customerSubtitle(CustomerDb customer) {
    final parts = <String>[];
    final code = customer.code?.trim() ?? '';
    final mobile = customer.mobile.trim();
    final phone = customer.phone?.trim() ?? '';

    if (code.isNotEmpty) {
      parts.add('كود: $code');
    }
    if (mobile.isNotEmpty) {
      parts.add(mobile);
    } else if (phone.isNotEmpty) {
      parts.add(phone);
    }

    if (parts.isEmpty) return null;
    return parts.join(' | ');
  }

  void _emitSelectedCustomer(String? value, List<CustomerDb> customers) {
    final callback = widget.onCustomerChanged;
    if (callback == null) return;

    final selected = (value ?? '').trim();
    if (selected.isEmpty || selected == _walkInCustomerValue) {
      callback(null, _walkInCustomerLabel);
      return;
    }

    if (!selected.startsWith('c_')) {
      callback(null, _walkInCustomerLabel);
      return;
    }

    final id = int.tryParse(selected.substring(2));
    if (id == null) {
      callback(null, _walkInCustomerLabel);
      return;
    }

    CustomerDb? customer;
    for (final row in customers) {
      if (row.id == id) {
        customer = row;
        break;
      }
    }

    if (customer == null) {
      callback(null, _walkInCustomerLabel);
      return;
    }

    callback(customer.id, _customerDisplayName(customer));
  }

  void _emitSelectedService(String? value, List<ServiceDb> services) {
    final callback = widget.onServiceChanged;
    if (callback == null) return;

    final selected = (value ?? '').trim();
    if (selected.isEmpty || selected == 'all') {
      callback(null, '', 0);
      return;
    }

    if (!selected.startsWith('s_')) {
      callback(null, '', 0);
      return;
    }

    final id = int.tryParse(selected.substring(2));
    if (id == null) {
      callback(null, '', 0);
      return;
    }

    ServiceDb? service;
    for (final row in services) {
      if (row.id == id) {
        service = row;
        break;
      }
    }

    if (service == null) {
      callback(null, '', 0);
      return;
    }

    final name = service.name.trim();
    callback(service.id, name, service.cost);
  }

  void _emitSelectedTable(String? value, List<PosTableDb> tables) {
    final callback = widget.onTableChanged;
    if (callback == null) return;

    final selected = (value ?? '').trim();
    if (selected.isEmpty || selected == 'none') {
      callback(null, '');
      return;
    }

    if (!selected.startsWith('t_')) {
      callback(null, '');
      return;
    }

    final id = int.tryParse(selected.substring(2));
    if (id == null) {
      callback(null, '');
      return;
    }

    PosTableDb? table;
    for (final row in tables) {
      if (row.id == id) {
        table = row;
        break;
      }
    }

    final name = table?.name.trim() ?? '';
    if (table == null || name.isEmpty) {
      callback(null, '');
      return;
    }
    callback(table.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDbProvider);
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: StreamBuilder<List<CustomerDb>>(
        stream: db.watchCustomers(),
        builder: (context, customerSnapshot) {
          final customers = customerSnapshot.data ?? const <CustomerDb>[];
          final customerOptions = <PosSelectOption<String>>[
            const PosSelectOption<String>(
              value: _walkInCustomerValue,
              label: _walkInCustomerLabel,
              subtitle: 'بدون حساب عميل محفوظ',
            ),
            ...customers.map(
              (customer) => PosSelectOption<String>(
                value: 'c_${customer.id}',
                label: _customerDisplayName(customer),
                subtitle: _customerSubtitle(customer),
              ),
            ),
          ];
          final effectiveCustomer =
              customerOptions.any((o) => o.value == _selectedCustomer)
              ? _selectedCustomer
              : customerOptions.first.value;
          if (effectiveCustomer != _selectedCustomer) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectedCustomer = effectiveCustomer);
              _emitSelectedCustomer(effectiveCustomer, customers);
            });
          }

          return StreamBuilder<List<ServiceDb>>(
            stream: db.watchServices(activeOnly: true),
            builder: (context, servicesSnapshot) {
              final services = servicesSnapshot.data ?? const <ServiceDb>[];
              final serviceOptions = <PosSelectOption<String>>[
                const PosSelectOption<String>(
                  value: 'all',
                  label: 'حدد نوع الخدمة',
                ),
                ...services.map(
                  (service) => PosSelectOption<String>(
                    value: 's_${service.id}',
                    label: service.name,
                  ),
                ),
              ];
              final effectiveService =
                  serviceOptions.any((o) => o.value == _selectedService)
                  ? _selectedService
                  : serviceOptions.first.value;
              if (effectiveService != _selectedService) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedService = effectiveService);
                  _emitSelectedService(effectiveService, services);
                });
              } else if (!widget.showServices && _selectedService != 'all') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedService = 'all');
                  _emitSelectedService('all', services);
                });
              }

              return StreamBuilder<List<PosTableDb>>(
                stream: db.watchPosTables(activeOnly: true),
                builder: (context, tablesSnapshot) {
                  final tables = tablesSnapshot.data ?? const <PosTableDb>[];
                  final tableOptions = <PosSelectOption<String>>[
                    const PosSelectOption<String>(
                      value: 'none',
                      label: 'اختر طاولة',
                    ),
                    ...tables.map(
                      (table) => PosSelectOption<String>(
                        value: 't_${table.id}',
                        label: table.name,
                      ),
                    ),
                  ];
                  final effectiveTable =
                      tableOptions.any((o) => o.value == _selectedTable)
                      ? _selectedTable
                      : tableOptions.first.value;
                  if (effectiveTable != _selectedTable) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _selectedTable = effectiveTable);
                      _emitSelectedTable(effectiveTable, tables);
                    });
                  } else if (!widget.showTables && _selectedTable != 'none') {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _selectedTable = 'none');
                      _emitSelectedTable('none', tables);
                    });
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.neutralGrey.withValues(alpha: 0.6),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            widget.compact || constraints.maxWidth < 980;
                        final serviceWidth = compact ? 148.0 : 175.0;
                        final tableWidth = compact ? 142.0 : 168.0;
                        final searchWidth = compact ? 170.0 : 260.0;
                        final customerWidth = compact ? 138.0 : 168.0;
                        final contentWidth = constraints.maxWidth;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: contentWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.showServices ||
                                    widget.showTables) ...[
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      textDirection: ui.TextDirection.rtl,
                                      children: [
                                        if (widget.showServices)
                                          PosSelect<String>(
                                            options: serviceOptions,
                                            value: effectiveService,
                                            hintText: 'حدد نوع الخدمة',
                                            width: serviceWidth,
                                            height: compact ? 28 : 30,
                                            leadingIcon: AppIcons.edit,
                                            leadingIconColor:
                                                AppColors.borderBlue,
                                            leadingIconBoxed: true,
                                            enableSearch: false,
                                            onChanged: (val) {
                                              setState(
                                                () => _selectedService = val,
                                              );
                                              _emitSelectedService(
                                                val,
                                                services,
                                              );
                                            },
                                          ),
                                        if (widget.showServices &&
                                            widget.showTables)
                                          SizedBox(width: compact ? 8 : 10),
                                        if (widget.showTables)
                                          PosSelect<String>(
                                            options: tableOptions,
                                            value: effectiveTable,
                                            hintText: 'اختر طاولة',
                                            width: tableWidth,
                                            height: compact ? 28 : 30,
                                            leadingIcon: AppIcons.table,
                                            leadingIconBoxed: true,
                                            enableSearch: false,
                                            onChanged: (val) {
                                              setState(
                                                () => _selectedTable = val,
                                              );
                                              _emitSelectedTable(val, tables);
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: compact ? 8 : 10),
                                ],
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      textDirection: ui.TextDirection.rtl,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PosSelect<String>(
                                              options: customerOptions,
                                              value: effectiveCustomer,
                                              hintText: _walkInCustomerLabel,
                                              width: customerWidth,
                                              height: compact ? 28 : 30,
                                              leadingIcon: AppIcons.user,
                                              leadingIconBoxed: true,
                                              minSearchChars: 1,
                                              dropdownItemExtent: 52,
                                              dropdownMinWidth: compact
                                                  ? 260
                                                  : 320,
                                              searchHintText:
                                                  'ابحث بالاسم أو الجوال أو الكود',
                                              validationText:
                                                  'اكتب حرفاً واحداً على الأقل',
                                              onChanged: (val) {
                                                setState(
                                                  () => _selectedCustomer = val,
                                                );
                                                _emitSelectedCustomer(
                                                  val,
                                                  customers,
                                                );
                                              },
                                            ),
                                            SizedBox(width: compact ? 6 : 8),
                                            _ActionCircle(
                                              icon: AppIcons.add,
                                              color: AppColors.borderBlue,
                                              compact: compact,
                                              onTap: () =>
                                                  CustomerAddDialog.show(
                                                    context,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(width: compact ? 10 : 14),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _SearchField(
                                              width: searchWidth,
                                              compact: compact,
                                            ),
                                            SizedBox(width: compact ? 6 : 8),
                                            _OutlineIconBox(
                                              icon: AppIcons.card,
                                              color: AppColors.borderBlue,
                                              compact: compact,
                                            ),
                                            SizedBox(width: compact ? 6 : 8),
                                            _ActionCircle(
                                              icon: AppIcons.add,
                                              color: AppColors.borderBlue,
                                              compact: compact,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _OutlineIconBox extends StatelessWidget {
  const _OutlineIconBox({
    required this.icon,
    required this.color,
    this.compact = false,
  });
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 24 : 28,
      height: compact ? 24 : 28,
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Icon(icon, size: compact ? 13 : 16, color: color),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.color,
    this.compact = false,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 10 : 12),
      child: Container(
        width: compact ? 20 : 24,
        height: compact ? 20 : 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: compact ? 13 : 16, color: Colors.white),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({this.width, this.compact = false});

  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 28.0 : 30.0;
    final iconBoxWidth = compact ? 28.0 : 30.0;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: iconBoxWidth,
            height: height,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.fieldBorder)),
            ),
            child: Icon(
              AppIcons.search,
              size: compact ? 13 : 16,
              color: const Color(0xFF333333),
            ),
          ),
          Expanded(
            child: TextField(
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ادخل اسم المنتج / الباركود / مسح الباركود',
                hintStyle: AppTextStyles.fieldHint.copyWith(
                  fontSize: compact ? 10 : 11,
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: compact ? 8 : 10,
                ),
                isDense: true,
              ),
              style: AppTextStyles.fieldText.copyWith(
                fontSize: compact ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
