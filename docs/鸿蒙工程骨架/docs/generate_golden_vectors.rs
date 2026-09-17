//! 黄金测试向量生成器
//!
//! 用途：用官方 fsrs crate 算出一批 (输入 → 期望输出)，导出为 JSON，
//!       作为 ArkTS 自研实现的单元测试基准。
//!
//! 运行（需要本机已装 Rust）：
//!   cargo new fsrs_golden && cd fsrs_golden
//!   # Cargo.toml 里加： fsrs = { version = "4", default-features = false }
//!   #                  serde_json = "1"
//!   # 把本文件放到 src/main.rs
//!   cargo run --release > vectors.json
//!
//! 然后把生成的 vectors.json 放到 golden_vectors/ 目录下，
//! 再跑 fsrs.selftest.ts，B 段断言就会自动生效。

use fsrs::{FSRS, MemoryState, Rating};
use serde_json::json;

fn main() {
    let fsrs = FSRS::new(None).expect("FSRS 初始化失败");

    let stabilities = [0.1f32, 1.0, 5.0, 10.0, 100.0, 1000.0];
    let difficulties = [1.0f32, 3.0, 5.0, 7.5, 10.0];
    let elapsed_list = [0u32, 1, 2, 3, 7, 14, 30, 90, 365];
    let ratings = [Rating::Again, Rating::Hard, Rating::Good, Rating::Easy];
    let retentions = [0.8f32, 0.85, 0.9, 0.95];

    let mut out = Vec::new();

    // ---- 分支一：新卡初始化 ----
    // 新卡没有 S / D，必须用 MemoryState::default() 或 None 走 init 分支
    for &rating in ratings.iter() {
        for &dr in retentions.iter() {
            let next = fsrs.next_states(
                None,          // state = None 表示新卡
                dr,
                0,             // elapsed_days
            ).expect("新卡调度失败");
            let s = next.by_rating(rating);
            out.push(json!({
                "is_new": true,
                "stability": 0.0,
                "difficulty": 0.0,
                "elapsed_days": 0,
                "rating": rating as u32,
                "desired_retention": dr,
                "expected_stability": s.memory.stability,
                "expected_difficulty": s.memory.difficulty,
                "expected_interval": s.interval,
            }));
        }
    }

    // ---- 分支二：老卡更新 ----
    for &s0 in stabilities.iter() {
        for &d0 in difficulties.iter() {
            for &el in elapsed_list.iter() {
                for &rating in ratings.iter() {
                    for &dr in retentions.iter() {
                        let state = Some(MemoryState {
                            stability: s0,
                            difficulty: d0,
                        });
                        let next = fsrs
                            .next_states(state, dr, el)
                            .expect("老卡调度失败");
                        let s = next.by_rating(rating);
                        out.push(json!({
                            "is_new": false,
                            "stability": s0,
                            "difficulty": d0,
                            "elapsed_days": el,
                            "rating": rating as u32,
                            "desired_retention": dr,
                            "expected_stability": s.memory.stability,
                            "expected_difficulty": s.memory.difficulty,
                            "expected_interval": s.interval,
                        }));
                    }
                }
            }
        }
    }

    let doc = json!({
        "generator": "fsrs crate (Rust)",
        "fsrs_version": env!("CARGO_PKG_VERSION"),
        "note": "由 fsrs crate 生成，作为自研 ArkTS 实现的比对基准",
        "vectors": out,
    });

    println!("{}", serde_json::to_string_pretty(&doc).unwrap());
}
