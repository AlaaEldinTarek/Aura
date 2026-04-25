import os, re

base = r"C:\Users\alaae\Desktop\Aura-App\android\app\src\main\res\layout"

# ── 1. Update widget info to 4x1 ──
info_path = r"C:\Users\alaae\Desktop\Aura-App\android\app\src\main\res\xml\combined_prayer_widget_info.xml"
with open(info_path, 'r', encoding='utf-8') as f:
    info = f.read()
info = info.replace('android:minHeight="110dp"', 'android:minHeight="50dp"')
info = info.replace('android:targetCellHeight="2"', 'android:targetCellHeight="1"')
with open(info_path, 'w', encoding='utf-8') as f:
    f.write(info)
print("Widget info updated to 4x1")

# ── 2. Compact View 0 template ──
def build_view0(dark, rtl):
    c = lambda light, dark_v: dark_v if dark else light
    primary = c("#2A2418","#F4F5F7"); accent = c("#B5821B","#F5B301"); sec = c("#7A6E5A","#A8ADB8")
    timer_c = c("#8A6110","#FFD37A"); muted = c("#9A8F78","#6B7180")
    pill = c("widget_v3_pill_light","widget_v3_pill_dark"); panel = c("widget_v3_panel_light","widget_v3_panel_dark")
    div = c("#1A3C2D14","#1EFFFFFF")
    t = rtl
    pname = "العصر" if t else "Asr"; ptime = "٠٣:٢٥" if t else "03:25"; ampm = "مساءً" if t else "PM"
    until = "حتى موعد الأذان" if t else "UNTIL AZAN"; loc = "الرياض" if t else "Riyadh"
    dow = "الثلاثاء" if t else "Tuesday"
    gl = "الميلادي" if t else "GREGORIAN"; gd = "٢١" if t else "21"; gm = "أبريل" if t else "Apr"; gy = "٢٠٢٦" if t else "2026"
    hl = "الهجري" if t else "HIJRI"; hd = "٤" if t else "4"; hm = "ذو القعدة" if t else "Dhu Q."; hy = "١٤٤٧ هـ" if t else "1447 AH"
    td = '\n                        android:textDirection="ltr"' if t else ''
    td2 = '\n                    android:textDirection="ltr"' if t else ''

    def col(label, day_id, day, month_id, month):
        return f'''                    <LinearLayout android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:orientation="vertical" android:gravity="center">
                        <TextView android:id="@+id/{label}" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="{label_tag}" android:textSize="5sp" android:textColor="{muted}" android:fontFamily="monospace" android:gravity="center" />
                        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:gravity="center">
                            <TextView android:id="@+id/{day_id}" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{day}" android:textSize="10sp" android:textColor="{primary}" android:fontFamily="sans-serif-medium" android:textStyle="bold" />
                            <TextView android:id="@+id/{month_id}" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{month}" android:textSize="10sp" android:textColor="{accent}" android:fontFamily="sans-serif-medium" android:textStyle="bold" android:layout_marginStart="2dp" />
                        </LinearLayout>
                    </LinearLayout>'''

    # RTL: hijri first; LTR: gregorian first
    if t:
        c1 = col("widget_hijri_label","widget_hijri_day",hd,"widget_hijri_month",hm)
        c1 = c1.replace('{label_tag}', hl)
        c2 = col("widget_gregorian_label","widget_gregorian_day",gd,"widget_gregorian_month",gm)
        c2 = c2.replace('{label_tag}', gl)
    else:
        c1 = col("widget_gregorian_label","widget_gregorian_day",gd,"widget_gregorian_month",gm)
        c1 = c1.replace('{label_tag}', gl)
        c2 = col("widget_hijri_label","widget_hijri_day",hd,"widget_hijri_month",hm)
        c2 = c2.replace('{label_tag}', hl)

    # Year line - separate since it's not in a column helper
    gy_line = f'<TextView android:id="@+id/widget_gregorian_year" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="{gy}" android:textSize="5sp" android:textColor="{muted}" android:fontFamily="monospace" android:gravity="center" />'
    hy_line = f'<TextView android:id="@+id/widget_hijri_year" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="{hy}" android:textSize="5sp" android:textColor="{muted}" android:fontFamily="monospace" android:gravity="center" />'

    return f'''        <!-- ═══ View 0: Next Prayer (compact 4x1) ═══ -->
        <LinearLayout android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="horizontal" android:gravity="center_vertical">
            <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1.4" android:orientation="vertical">
                <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:gravity="center_vertical">
                    <TextView android:id="@+id/widget_next_prayer_name" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{pname}" android:textSize="22sp" android:textColor="{primary}" android:textStyle="bold" android:fontFamily="sans-serif-medium" android:maxLines="1" android:ellipsize="end" />
                    <TextView android:id="@+id/widget_next_prayer_time" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{ptime}" android:textSize="14sp" android:textColor="{accent}" android:fontFamily="monospace"{td2} android:layout_marginStart="6dp" />
                    <TextView android:id="@+id/widget_next_prayer_ampm" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{ampm}" android:textSize="10sp" android:textColor="{sec}" android:layout_marginStart="2dp" />
                </LinearLayout>
                <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:orientation="horizontal" android:gravity="center_vertical" android:layout_marginTop="3dp" android:background="@drawable/{pill}" android:paddingStart="8dp" android:paddingEnd="8dp" android:paddingTop="2dp" android:paddingBottom="2dp" android:minHeight="18dp">
                    <ImageView android:id="@+id/widget_progress_bar" android:layout_width="16dp" android:layout_height="16dp" android:scaleType="fitCenter" />
                    <Chronometer android:id="@+id/widget_time_remaining" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textSize="10sp" android:textColor="{timer_c}" android:fontFamily="monospace" android:countDown="true"{td} android:layout_marginStart="4dp" />
                    <TextView android:id="@+id/widget_time_remaining_seconds" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{until}" android:textSize="6sp" android:textColor="{sec}" android:fontFamily="monospace" android:layout_marginStart="2dp" />
                </LinearLayout>
            </LinearLayout>
            <LinearLayout android:layout_width="90dp" android:layout_height="match_parent" android:orientation="vertical" android:background="@drawable/{panel}" android:padding="5dp" android:layout_marginStart="6dp">
                <TextView android:id="@+id/widget_day_of_week" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="{dow}" android:textSize="7sp" android:textColor="{accent}" android:fontFamily="sans-serif-medium" android:textStyle="bold" android:gravity="center" />
                <LinearLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1" android:orientation="horizontal" android:layout_marginTop="1dp">
                    {c1}
                    {gy_line}
                    <FrameLayout android:layout_width="1dp" android:layout_height="match_parent" android:layout_marginStart="2dp" android:layout_marginEnd="2dp" android:background="{div}" />
                    {c2}
                    {hy_line}
                </LinearLayout>
            </LinearLayout>
        </LinearLayout>'''

# ── 3. Compact View 1 template (dots only, no top section) ──
def build_view1(dark, rtl):
    c = lambda l, d: d if dark else l
    accent = c("#B5821B","#F5B301"); sec = c("#7A6E5A","#A8ADB8")
    muted = c("#9A8F78","#6B7180"); primary = c("#2A2418","#F4F5F7")
    timer_c = c("#8A6110","#FFD37A")

    prayers = [
        ("0","Fajr","الفجر","04:21","٠٤:٢١"),
        ("1","Shuruq","الشروق","05:47","٠٥:٤٧"),
        ("2","Zuhr","الظهر","11:52","١١:٥٢"),
        ("3","Asr","العصر","15:14","١٥:١٤"),
        ("4","Maghrib","المغرب","18:29","١٨:٢٩"),
        ("5","Isha","العشاء","19:52","١٩:٥٢"),
    ]

    cols = []
    for i, en_name, ar_name, en_time, ar_time in prayers:
        name = ar_name if rtl else en_name
        time = ar_time if rtl else en_time
        td = ' android:textDirection="ltr"' if rtl else ''
        cols.append(f'''                <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:orientation="vertical" android:gravity="center_horizontal">
                    <ImageView android:id="@+id/timeline_dot_{i}" android:layout_width="10dp" android:layout_height="10dp" android:scaleType="fitCenter" />
                    <TextView android:id="@+id/timeline_name_{i}" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{name}" android:textSize="6sp" android:textColor="{muted}" android:maxLines="1" android:layout_marginTop="1dp" />
                    <TextView android:id="@+id/timeline_time_{i}" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{time}" android:textSize="5sp" android:textColor="{muted}" android:fontFamily="monospace"{td} />
                </LinearLayout>''')

    # Hidden elements for Kotlin compatibility (0dp, won't show)
    hidden = f'''            <TextView android:id="@+id/timeline_current_name" android:layout_width="0dp" android:layout_height="0dp" android:text="Zuhr" android:textSize="0sp" />
            <TextView android:id="@+id/timeline_current_time" android:layout_width="0dp" android:layout_height="0dp" android:text="11:52" android:textSize="0sp" />
            <TextView android:id="@+id/timeline_current_ampm" android:layout_width="0dp" android:layout_height="0dp" android:text="AM" android:textSize="0sp" />
            <TextView android:id="@+id/timeline_next_label" android:layout_width="0dp" android:layout_height="0dp" android:text="NEXT" android:textSize="0sp" />
            <TextView android:id="@+id/timeline_countdown_text" android:layout_width="0dp" android:layout_height="0dp" android:text="1h 02m" android:textSize="0sp" />
            <TextView android:id="@+id/timeline_secondary_info" android:layout_width="0dp" android:layout_height="0dp" android:text="TUE 21 APR" android:textSize="0sp" />'''

    dots = '\n'.join(cols)
    return f'''        <!-- ═══ View 1: Day Timeline (compact 4x1) ═══ -->
        <LinearLayout android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical">
{hidden}
            <FrameLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_gravity="center_vertical">
                <ImageView android:id="@+id/timeline_progress_bar" android:layout_width="match_parent" android:layout_height="4dp" android:layout_gravity="top" android:layout_marginTop="3dp" android:scaleType="fitXY" />
                <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal"{" android:layoutDirection=\"ltr\"" if rtl else ""}>
{dots}
                </LinearLayout>
            </FrameLayout>
        </LinearLayout>'''

# ── 4. Process all files ──
files = [
    ("combined_prayer_widget.xml", False, False),
    ("combined_prayer_widget_dark.xml", True, False),
    ("combined_prayer_widget_rtl.xml", False, True),
    ("combined_prayer_widget_dark_rtl.xml", True, True),
]

for fname, dark, rtl in files:
    path = os.path.join(base, fname)
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Root padding
    content = content.replace('android:paddingStart="14dp"', 'android:paddingStart="8dp"')
    content = content.replace('android:paddingEnd="14dp"', 'android:paddingEnd="8dp"')
    content = content.replace('android:paddingTop="10dp"', 'android:paddingTop="4dp"')
    content = content.replace('android:paddingBottom="10dp"', 'android:paddingBottom="4dp"')

    # Tab bar: smaller height, text, padding, margin
    content = content.replace('android:layout_marginBottom="6dp">', 'android:layout_marginBottom="2dp">')
    content = content.replace('android:layout_height="28dp"\n            android:text="Next Prayer"', 'android:layout_height="18dp"\n            android:text="Next Prayer"')
    content = content.replace('android:layout_height="28dp"\n            android:text="Timeline"', 'android:layout_height="18dp"\n            android:text="Timeline"')
    content = content.replace('android:layout_height="28dp"\n            android:text="الصلاة القادمة"', 'android:layout_height="18dp"\n            android:text="الصلاة القادمة"')
    content = content.replace('android:layout_height="28dp"\n            android:text="الجدول"', 'android:layout_height="18dp"\n            android:text="الجدول"')

    # Tab text size (10sp → 7sp) - only in tab bar context
    # Replace 10sp that appears after textColor line in tabs
    for _ in range(2):  # two tabs per file
        content = content.replace('android:textSize="10sp"\n            android:textColor="', 'android:textSize="7sp"\n            android:textColor="', 1)

    # Tab padding (12dp → 6dp)
    content = content.replace('android:paddingStart="12dp"\n            android:paddingEnd="12dp"', 'android:paddingStart="6dp"\n            android:paddingEnd="6dp"')

    # Replace View 0
    v0 = build_view0(dark, rtl)
    start_m = '<!-- ═══ View 0:'
    end_m = '<!-- ═══ View 1:'
    si = content.find(start_m)
    ei = content.find(end_m)
    if si >= 0 and ei >= 0:
        ls = content.rfind('\n', 0, si) + 1
        content = content[:ls] + v0 + '\n\n        ' + content[ei:]

    # Replace View 1
    v1 = build_view1(dark, rtl)
    start_m2 = '<!-- ═══ View 1:'
    end_m2 = '</ViewFlipper>'
    si2 = content.find(start_m2)
    ei2 = content.find(end_m2)
    if si2 >= 0 and ei2 >= 0:
        ls2 = content.rfind('\n', 0, si2) + 1
        content = content[:ls2] + v1 + '\n    ' + content[ei2:]

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Updated {fname}")

print("All files updated to 4x1!")
