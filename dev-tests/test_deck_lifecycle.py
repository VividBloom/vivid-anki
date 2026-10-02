#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
牌组 / 卡片生命周期回归测试（审查报告 N-01 方案 A）

在真实 SQLite 上复现 DeckLifecycleService 的 SQL 语义。
不依赖鸿蒙环境，可直接运行：

    python3 dev-tests/test_deck_lifecycle.py

覆盖场景：
  1. 删除牌组 → 卡片软删，不物理删除
  2. 30 天内可恢复
  3. 恢复不捞回用户主动删除的卡片（deleted_by_deck 隔离）
  4. 超期清理后 revlog 必须完整保留
  5. 牌组下仍有未过期卡片时，牌组不得硬删（否则恢复后无归属）
  6. 卡片清理后过期牌组随之清除
  7. 全新卡片（未复习过）同样受保护
"""

import os
import sqlite3
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SQL_PATH = os.path.join(ROOT, 'docs', 'V1__init.sql')

DAY = 86400000
NOW = 1768600000000

_ok = True


def chk(name, cond, extra=""):
    global _ok
    print(("  OK   " if cond else "  FAIL ") + name + (" " + extra if extra else ""))
    if not cond:
        _ok = False


def main():
    with open(SQL_PATH, encoding='utf-8') as f:
        sql = f.read()
    con = sqlite3.connect(':memory:')
    con.execute('PRAGMA foreign_keys = ON')
    con.executescript(sql)
    c = con.cursor()

    def purge(cut_ms):
        n = c.execute(
            'SELECT COUNT(*) FROM card WHERE deleted_at IS NOT NULL AND deleted_at < ?',
            (cut_ms,)).fetchone()[0]
        c.execute('DELETE FROM card WHERE deleted_at IS NOT NULL AND deleted_at < ?', (cut_ms,))
        c.execute(
            'DELETE FROM deck WHERE deleted_at IS NOT NULL AND deleted_at < ? '
            'AND NOT EXISTS (SELECT 1 FROM card x WHERE x.deck_id = deck.id)', (cut_ms,))
        return n

    def newdeck(name):
        c.execute('INSERT INTO deck(name,created_at,updated_at) VALUES (?,?,?)', (name, NOW, NOW))
        return c.lastrowid

    def newcard(did, front):
        c.execute(
            'INSERT INTO card(deck_id,front,back,state,due,stability,difficulty,reps,lapses,'
            'created_at,updated_at) VALUES (?,?,?,?,?,10,5,3,0,?,?)',
            (did, front, 'A', 'review', NOW, NOW, NOW))
        return c.lastrowid

    def addrev(cid, n=3):
        for i in range(n):
            c.execute(
                'INSERT INTO revlog(card_id,rating,elapsed_days,stability_before,difficulty_before,'
                'reps_before,lapses_before,stability_after,difficulty_after,interval_after,'
                'reviewed_at,created_at) VALUES (?,3,?,9,5,?,0,10,5,10,?,0)', (cid, i + 1, i, NOW))

    def soft_delete_deck(did, ts):
        c.execute('UPDATE card SET deleted_at=?, deleted_by_deck=1, updated_at=? '
                  'WHERE deck_id=? AND deleted_at IS NULL', (ts, ts, did))
        c.execute('UPDATE deck SET deleted_at=?, card_count=0, due_count=0, updated_at=? '
                  'WHERE id=? AND deleted_at IS NULL', (ts, ts, did))

    def restore_deck(did, ts):
        da = c.execute('SELECT deleted_at FROM deck WHERE id=?', (did,)).fetchone()[0]
        c.execute('UPDATE card SET deleted_at=NULL, deleted_by_deck=0, updated_at=? '
                  'WHERE deck_id=? AND deleted_at=? AND deleted_by_deck=1', (ts, did, da))
        c.execute('UPDATE deck SET deleted_at=NULL, updated_at=? WHERE id=?', (ts, did))

    def alive(did):
        return c.execute('SELECT COUNT(*) FROM card WHERE deck_id=? AND deleted_at IS NULL',
                         (did,)).fetchone()[0]

    print('场景1 删除牌组 -> 卡片软删而非物理删除')
    d1 = newdeck('英语')
    ids = [newcard(d1, 'Q%d' % i) for i in range(3)]
    for i in ids:
        addrev(i)
    soft_delete_deck(d1, NOW)
    chk('活跃卡片归零', alive(d1) == 0)
    chk('3 张转入软删', c.execute(
        'SELECT COUNT(*) FROM card WHERE deck_id=? AND deleted_at IS NOT NULL', (d1,)).fetchone()[0] == 3)

    print('场景2 30 天内可恢复')
    restore_deck(d1, NOW)
    chk('3 张全部恢复', alive(d1) == 3)

    print('场景3 恢复不捞回用户主动删除的卡片')
    c4 = newcard(d1, 'Q4主动删')
    c.execute('UPDATE card SET deleted_at=?, deleted_by_deck=0, updated_at=? WHERE id=?', (NOW, NOW, c4))
    soft_delete_deck(d1, NOW)
    restore_deck(d1, NOW)
    chk('主动删除的仍保留删除态', c.execute(
        'SELECT COUNT(*) FROM card WHERE id=? AND deleted_at IS NOT NULL', (c4,)).fetchone()[0] == 1)
    chk('随牌组删除的已恢复', alive(d1) == 3)

    print('场景4 超期清理，revlog 必须保留')
    soft_delete_deck(d1, NOW - 31 * DAY)
    rev_before = c.execute('SELECT COUNT(*) FROM revlog').fetchone()[0]
    n = purge(NOW - 30 * DAY)
    rev_after = c.execute('SELECT COUNT(*) FROM revlog').fetchone()[0]
    chk('硬删了过期卡片', n > 0, '(%d 张)' % n)
    chk('revlog 一条不丢', rev_before == rev_after, '(%d->%d)' % (rev_before, rev_after))
    chk('revlog 可独立训练', all(
        r[0] is not None for r in c.execute('SELECT stability_before FROM revlog').fetchall()))

    print('场景5 牌组下仍有未过期卡片时，牌组不得硬删')
    d2 = newdeck('医学')
    c5 = newcard(d2, 'M1')
    c.execute('UPDATE card SET deleted_at=?, deleted_by_deck=1 WHERE id=?', (NOW - 10 * DAY, c5))
    c.execute('UPDATE deck SET deleted_at=? WHERE id=?', (NOW - 31 * DAY, d2))
    purge(NOW - 30 * DAY)
    chk('牌组保留（否则卡片恢复后无归属）',
        c.execute('SELECT COUNT(*) FROM deck WHERE id=?', (d2,)).fetchone()[0] == 1)
    chk('卡片保留', c.execute('SELECT COUNT(*) FROM card WHERE id=?', (c5,)).fetchone()[0] == 1)

    print('场景6 卡片清理后牌组随之清除')
    purge(NOW + 1)
    chk('牌组已清除', c.execute('SELECT COUNT(*) FROM deck WHERE id=?', (d2,)).fetchone()[0] == 0)

    print('场景7 全新卡片（未复习过）同样受保护')
    d3 = newdeck('新牌组')
    c6 = newcard(d3, 'N1')
    soft_delete_deck(d3, NOW)
    chk('新卡进入软删', c.execute(
        'SELECT COUNT(*) FROM card WHERE id=? AND deleted_at IS NOT NULL', (c6,)).fetchone()[0] == 1)

    print('=' * 50)
    print('全部通过' if _ok else '存在失败')
    return 0 if _ok else 1


if __name__ == '__main__':
    sys.exit(main())
