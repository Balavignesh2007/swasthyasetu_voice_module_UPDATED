import sqlite3

conn = sqlite3.connect('swasthyasetu.db')
c = conn.cursor()
for t in ['asha_workers', 'patients', 'facilities', 'appointments']:
    cols = [col[1] for col in c.execute(f"PRAGMA table_info({t})").fetchall()]
    print(t, cols)
    rows = c.execute(f"SELECT * FROM {t}").fetchall()
    print(f"Count {t}: {len(rows)}")
    for r in rows[:5]:
        print("  ", r)
