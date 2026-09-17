import sqlite3
import os

db_paths = [
    r'c:\Users\balas\Project\swasthyasetu_voice_module_UPDATED\swasthyasetu_voice_module - Copy\backend\swasthyasetu.db',
    r'c:\Users\balas\Project\swasthyasetu_voice_module_UPDATED\swasthyasetu_voice_module - Copy\swasthyasetu.db',
]

for p in db_paths:
    if not os.path.exists(p):
        print(f"Skipping non-existent {p}")
        continue
    print(f"Updating {p}...")
    conn = sqlite3.connect(p)
    cur = conn.cursor()

    # 1. Update facilities: Anantapur District Hospital -> Pune District Hospital (Aundh)
    cur.execute("""
        UPDATE facilities
        SET name = 'Pune District Hospital (Aundh)',
            district = 'Pune',
            address = 'Aundh Chest Hospital Campus, Pune — 411027'
        WHERE name LIKE '%Anantapur%' OR district LIKE '%Anantapur%'
    """)

    # 2. Update patients: replace Anantapur Central and Rampur with Maharashtra villages
    cur.execute("""
        UPDATE patients
        SET village = 'Shivaji Nagar, Pune'
        WHERE village LIKE '%Anantapur%'
    """)
    cur.execute("""
        UPDATE patients
        SET village = 'Kothrud, Pune'
        WHERE village = 'Rampur'
    """)
    cur.execute("""
        UPDATE patients
        SET village = 'Shivaji Nagar, Pune'
        WHERE village LIKE 'Rampur%'
    """)
    cur.execute("""
        UPDATE patients
        SET village = 'Hadapsar, Pune'
        WHERE village = 'Central Village'
    """)

    # 3. Update any appointment notes or diagnoses mentioning Anantapur or Rampur
    cur.execute("""
        UPDATE appointments
        SET notes = REPLACE(notes, 'Anantapur', 'Pune')
        WHERE notes LIKE '%Anantapur%'
    """)
    cur.execute("""
        UPDATE appointments
        SET notes = REPLACE(notes, 'Rampur', 'Shivaji Nagar')
        WHERE notes LIKE '%Rampur%'
    """)

    conn.commit()
    print(f"Updated {p} successfully.")

    # Print summary of facilities and patients
    print("Facilities:")
    for f in cur.execute("SELECT id, name, district, address FROM facilities").fetchall():
        print("  ", f)
    print("Patients (sample):")
    for pat in cur.execute("SELECT id, name, village FROM patients").fetchall():
        print("  ", pat)
    conn.close()
