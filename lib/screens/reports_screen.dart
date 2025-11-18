import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/scan_history_service.dart';
import '../services/export_service.dart';
import '../models/scan_result.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
  final ExportService _exportService = ExportService();
  late TabController _tabController;
  Map<String, dynamic> _statistics = {};
  List<ScanResult> _allScans = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String _selectedRange = '7'; // '7', '30', 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats = await _scanHistoryService.getStatistics();
    final scans = await _scanHistoryService.getScanHistory();
    setState(() {
      _statistics = stats;
      _allScans = scans;
      _isLoading = false;
    });
  }

  Future<void> _exportToPdf() async {
    setState(() => _isExporting = true);
    try {
      final path = await _exportService.exportToPdf(_statistics, _allScans);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất PDF: $path'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Chia sẻ',
              textColor: Colors.white,
              onPressed: () => _exportService.shareFile(path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    try {
      final path = await _exportService.exportToCsv(_allScans);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất CSV: $path'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Chia sẻ',
              textColor: Colors.white,
              onPressed: () => _exportService.shareFile(path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Báo cáo chi tiết',
          style: TextStyle(
            color: Color(0xFF202124),
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5F6368)),
        actions: [
          if (!_isLoading && _allScans.isNotEmpty)
            PopupMenuButton(
              icon: _isExporting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Xuất PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, size: 20, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Xuất CSV'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'pdf') {
                  _exportToPdf();
                } else if (value == 'csv') {
                  _exportToCsv();
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4285F4),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4285F4),
          tabs: const [
            Tab(text: 'Xu hướng'),
            Tab(text: 'Chi tiết'),
            Tab(text: 'Phân tích'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allScans.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTrendsTab(),
                    _buildDetailsTab(),
                    _buildAnalysisTab(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Chưa có báo cáo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Kiểm tra email để tạo báo cáo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    final scansForChart = _getScansForRange();
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ChoiceChip(
                  label: const Text('7 ngày'),
                  selected: _selectedRange == '7',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedRange = '7');
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('30 ngày'),
                  selected: _selectedRange == '30',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedRange = '30');
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _selectedRange == 'all',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedRange = 'all');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTimelineChart(scansForChart),
            const SizedBox(height: 24),
            _buildDailyBreakdown(),
          ],
        ),
      ),
    );
  }

  List<ScanResult> _getScansForRange() {
    if (_allScans.isEmpty) {
      return [];
    }

    if (_selectedRange == 'all') {
      return _allScans;
    }

    final days = int.tryParse(_selectedRange) ?? 7;
    final now = DateTime.now();

    final filtered = _allScans
        .where((scan) => now.difference(scan.scanDate).inDays <= days)
        .toList();

    if (filtered.isEmpty) {
      return _allScans;
    }

    return filtered;
  }

  Widget _buildTimelineChart(List<ScanResult> scans) {
    final Map<String, Map<String, int>> dailyData = {};
    
    for (var scan in scans) {
      final dateKey = DateFormat('dd/MM').format(scan.scanDate);
      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = {'phishing': 0, 'suspicious': 0, 'safe': 0};
      }
      
      if (scan.isPhishing) {
        dailyData[dateKey]!['phishing'] = (dailyData[dateKey]!['phishing'] ?? 0) + 1;
      } else if (scan.isSuspicious) {
        dailyData[dateKey]!['suspicious'] = (dailyData[dateKey]!['suspicious'] ?? 0) + 1;
      } else {
        dailyData[dateKey]!['safe'] = (dailyData[dateKey]!['safe'] ?? 0) + 1;
      }
    }

    final sortedEntries = dailyData.entries.toList()
      ..sort((a, b) {
        final aDate = DateFormat('dd/MM').parse(a.key);
        final bDate = DateFormat('dd/MM').parse(b.key);
        return aDate.compareTo(bDate);
      });

    final labels = sortedEntries.map((e) => e.key).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedRange == 'all'
                ? 'Xu hướng toàn bộ thời gian'
                : _selectedRange == '30'
                    ? 'Xu hướng 30 ngày qua'
                    : 'Xu hướng 7 ngày qua',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: dailyData.isEmpty
                ? Center(
                    child: Text(
                      'Không có dữ liệu',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < labels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    labels[value.toInt()],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(sortedEntries.length, (index) {
                            final data = sortedEntries[index].value;
                            return FlSpot(
                              index.toDouble(),
                              (data['phishing'] ?? 0).toDouble(),
                            );
                          }),
                          isCurved: true,
                          color: const Color(0xFFEA4335),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                        LineChartBarData(
                          spots: List.generate(sortedEntries.length, (index) {
                            final data = sortedEntries[index].value;
                            return FlSpot(
                              index.toDouble(),
                              (data['suspicious'] ?? 0).toDouble(),
                            );
                          }),
                          isCurved: true,
                          color: const Color(0xFFFBBC04),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                        LineChartBarData(
                          spots: List.generate(sortedEntries.length, (index) {
                            final data = sortedEntries[index].value;
                            return FlSpot(
                              index.toDouble(),
                              (data['safe'] ?? 0).toDouble(),
                            );
                          }),
                          isCurved: true,
                          color: const Color(0xFF34A853),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend('Nguy hiểm', const Color(0xFFEA4335)),
              const SizedBox(width: 24),
              _buildChartLegend('Nghi ngờ', const Color(0xFFFBBC04)),
              const SizedBox(width: 24),
              _buildChartLegend('An toàn', const Color(0xFF34A853)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildDailyBreakdown() {
    final emailsByDate = <String, List<ScanResult>>{};
    
    for (var scan in _allScans) {
      final dateKey = DateFormat('dd/MM/yyyy').format(scan.scanDate);
      if (!emailsByDate.containsKey(dateKey)) {
        emailsByDate[dateKey] = [];
      }
      emailsByDate[dateKey]!.add(scan);
    }

    final sortedDates = emailsByDate.keys.toList()
      ..sort((a, b) => DateFormat('dd/MM/yyyy').parse(b).compareTo(DateFormat('dd/MM/yyyy').parse(a)));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân tích theo ngày',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...sortedDates.take(7).map((date) {
            final scans = emailsByDate[date]!;
            final phishingCount = scans.where((s) => s.isPhishing).length;
            final suspiciousCount = scans.where((s) => s.isSuspicious).length;
            final safeCount = scans.where((s) => s.isSafe).length;
            
            return _buildDayItem(date, phishingCount, suspiciousCount, safeCount);
          }),
        ],
      ),
    );
  }

  Widget _buildDayItem(String date, int phishing, int suspicious, int safe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDayCount('Nguy hiểm', phishing, const Color(0xFFEA4335)),
              ),
              Expanded(
                child: _buildDayCount('Nghi ngờ', suspicious, const Color(0xFFFBBC04)),
              ),
              Expanded(
                child: _buildDayCount('An toàn', safe, const Color(0xFF34A853)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDetailsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _allScans.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final scan = _allScans[_allScans.length - 1 - index];
          return _buildDetailCard(scan);
        },
      ),
    );
  }

  Widget _buildDetailCard(ScanResult scan) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (scan.isPhishing) {
      statusColor = const Color(0xFFEA4335);
      statusText = 'Nguy hiểm';
      statusIcon = Icons.dangerous;
    } else if (scan.isSuspicious) {
      statusColor = const Color(0xFFFBBC04);
      statusText = 'Nghi ngờ';
      statusIcon = Icons.warning_amber;
    } else {
      statusColor = const Color(0xFF34A853);
      statusText = 'An toàn';
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(scan.scanDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(scan.confidenceScore * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            scan.subject,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Từ: ${scan.from}',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          if (scan.detectedThreats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: scan.detectedThreats.map((threat) => 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    threat,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    final phishingEmails = _allScans.where((s) => s.isPhishing).toList();
    final suspiciousEmails = _allScans.where((s) => s.isSuspicious).toList();
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalysisCard(
              'Email nguy hiểm',
              phishingEmails.length.toString(),
              'Phát hiện dấu hiệu phishing rõ ràng',
              Icons.dangerous,
              const Color(0xFFEA4335),
            ),
            const SizedBox(height: 12),
            _buildAnalysisCard(
              'Email nghi ngờ',
              suspiciousEmails.length.toString(),
              'Cần xem xét kỹ hơn',
              Icons.warning_amber,
              const Color(0xFFFBBC04),
            ),
            const SizedBox(height: 24),
            _buildCommonThreats(),
            const SizedBox(height: 24),
            _buildRecommendations(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(String title, String count, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonThreats() {
    final threatTrends = _statistics['threatTrends'] as Map<String, int>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mối đe dọa phổ biến',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (threatTrends.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Không có mối đe dọa nào được phát hiện',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ...threatTrends.entries.map((entry) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber[700]),
              const SizedBox(width: 8),
              const Text(
                'Khuyến nghị bảo mật',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem(
            'Không nhấp vào link lạ',
            'Luôn kiểm tra URL trước khi nhấp vào bất kỳ liên kết nào trong email',
          ),
          _buildRecommendationItem(
            'Xác minh người gửi',
            'Kiểm tra địa chỉ email người gửi có khớp với domain chính thức không',
          ),
          _buildRecommendationItem(
            'Cảnh giác với email khẩn cấp',
            'Email yêu cầu hành động gấp thường là dấu hiệu của phishing',
          ),
          _buildRecommendationItem(
            'Bật xác thực 2 yếu tố',
            'Thêm lớp bảo mật cho tài khoản quan trọng',
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF4285F4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
