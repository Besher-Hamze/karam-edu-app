import 'package:flutter/material.dart';

class SemesterSelector extends StatelessWidget {
  final int currentYear;
  final int currentSemester;
  final String currentMajor;
  final Function(int) onYearChanged;
  final Function(int) onSemesterChanged;
  final Function(String) onMajorChanged;

  const SemesterSelector({
    Key? key,
    required this.currentYear,
    required this.currentSemester,
    required this.currentMajor,
    required this.onYearChanged,
    required this.onSemesterChanged,
    required this.onMajorChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // List of majors with icons
    final List<Map<String, dynamic>> majors = [
      {'name': 'حواسيب', 'icon': Icons.computer_rounded},
      {'name': 'اتصالات', 'icon': Icons.wifi_rounded},
      {'name': 'ميكاترونيك', 'icon': Icons.precision_manufacturing_rounded},
      {'name': 'تحكم', 'icon': Icons.settings_input_component_rounded},
      {'name': 'قدرة', 'icon': Icons.flash_on_rounded},
      {'name': 'قيادة', 'icon': Icons.account_tree_rounded},
      {'name': 'الكترونية', 'icon': Icons.memory_rounded}
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6366F1).withOpacity(0.15),
                      Color(0xFF8B5CF6).withOpacity(0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Color(0xFF6366F1).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF6366F1),
                  size: 22,
                ),
              ),
              SizedBox(width: 14),
              Text(
                'اختر التخصص والمستوى',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D2E),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Premium Major Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 4, bottom: 10),
                child: Text(
                  'التخصص',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5568),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Color(0xFFF8F9FC),
                  border: Border.all(
                    color: Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  hint: Row(
                    children: [
                      Icon(
                        Icons.school_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "اختر القسم",
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  value: currentMajor == "" ? null : currentMajor,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    border: InputBorder.none,
                  ),
                  dropdownColor: Colors.white,
                  icon: Container(
                    margin: EdgeInsets.only(left: 12),
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  items: majors.map((major) {
                    return DropdownMenuItem<String>(
                      value: major['name'],
                      child: Row(
                        children: [
                          Icon(
                            major['icon'],
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            major['name'],
                            style: TextStyle(
                              color: Color(0xFF1A1D2E),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onMajorChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          Row(
            children: [
              // Premium Year Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: 4, bottom: 10),
                      child: Text(
                        'السنة الدراسية',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A5568),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Color(0xFFF8F9FC),
                        border: Border.all(
                          color: Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<int>(
                        value: currentYear,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                        ),
                        dropdownColor: Colors.white,
                        icon: Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF3B82F6),
                            size: 18,
                          ),
                        ),
                        items: [1, 2, 3, 4, 5].map((year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: Color(0xFF3B82F6),
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'السنة $year',
                                  style: TextStyle(
                                    color: Color(0xFF1A1D2E),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            onYearChanged(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 16),

              // Premium Semester Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: 4, bottom: 10),
                      child: Text(
                        'الفصل الدراسي',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A5568),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Color(0xFFF8F9FC),
                        border: Border.all(
                          color: Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<int>(
                        value: currentSemester,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                        ),
                        dropdownColor: Colors.white,
                        icon: Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                        ),
                        items: [1, 2].map((semester) {
                          return DropdownMenuItem<int>(
                            value: semester,
                            child: Row(               
                              children: [
                                Icon(
                                  Icons.event_note_rounded,
                                  color: Color(0xFF10B981),
                                  size: 18,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'الفصل $semester',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1A1D2E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            onSemesterChanged(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}