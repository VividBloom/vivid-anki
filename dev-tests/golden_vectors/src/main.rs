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

use fsrs::{FSRS, MemoryState};
use serde_json::json;

fn main() {
    let weights = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835,
        0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542,
    ];
    let fsrs = FSRS::new(Some(&weights)).expect("FSRS 初始化失败");
    let decay = weights[20];
    let factor = 0.9f32.powf(1.0 / decay) - 1.0;
    eprintln!("Factor: {}", factor);

    let stabilities = [0.1f32, 1.0, 5.0, 10.0, 100.0, 1000.0];
    let difficulties = [1.0f32, 3.0, 5.0, 7.5, 10.0];
    let elapsed_list = [0u32, 1, 2, 3, 7, 14, 30, 90, 365];
    
    // In fsrs v4, ratings are often handled directly via struct fields: again, hard, good, easy
    let retentions = [0.8f32, 0.85, 0.9, 0.95];

    let mut out = Vec::new();

    // Helper closure to push a record for a specific rating
    let mut push_record = |is_new: bool, s0: f32, d0: f32, el: u32, dr: f32, rating: u32, next_item: &fsrs::ItemState| {
        out.push(json!({
            "is_new": is_new,
            "stability": s0,
            "difficulty": d0,
            "elapsed_days": el,
            "rating": rating,
            "desired_retention": dr,
            "expected_stability": next_item.memory.stability,
            "expected_difficulty": next_item.memory.difficulty,
            "expected_interval": next_item.interval,
        }));
    };

    // ---- 分支一：新卡初始化 ----
    for &dr in retentions.iter() {
        let next = fsrs.next_states(
            None,
            dr,
            0,
        ).expect("新卡调度失败");
        
        push_record(true, 0.0, 0.0, 0, dr, 1, &next.again);
        push_record(true, 0.0, 0.0, 0, dr, 2, &next.hard);
        push_record(true, 0.0, 0.0, 0, dr, 3, &next.good);
        push_record(true, 0.0, 0.0, 0, dr, 4, &next.easy);
    }

    // ---- 分支二：老卡更新 ----
    for &s0 in stabilities.iter() {
        for &d0 in difficulties.iter() {
            for &el in elapsed_list.iter() {
                for &dr in retentions.iter() {
                    let state = Some(MemoryState {
                        stability: s0,
                        difficulty: d0,
                    });
                    let next = fsrs
                        .next_states(state, dr, el)
                        .expect("老卡调度失败");
                    
                    if (s0 == 1000.0 && el == 14 && dr == 0.8 && d0 == 1.0) {
                        let r = fsrs.current_retrievability(MemoryState { stability: s0, difficulty: d0 }, el, weights[20]);
                        let t_r = (weights[10] * (1.0 - r)).exp() - 1.0;
                        let t_d = 11.0 - d0;
                        let t_s = s0.powf(-weights[9]);
                        let boost = weights[8].exp();
                        eprintln!("Probe Group 3700: S={}, D={}, el={}, dr={}", s0, d0, el, dr);
                        eprintln!("  r={}", r);
                        eprintln!("  t_r={}", t_r);
                        eprintln!("  t_d={}", t_d);
                        eprintln!("  t_s={}", t_s);
                        eprintln!("  boost={}", boost);
                        eprintln!("  next_s={}", next.easy.memory.stability);
                    }

                    if (s0 == 100.0 && el == 1 && dr == 0.9 && d0 == 3.0) {
                        eprintln!("Probe Group Again: S={}, D={}, el={}, dr={}, rating=1", s0, d0, el, dr);
                        eprintln!("  next_s={}", next.again.memory.stability);
                    }

                    push_record(false, s0, d0, el, dr, 1, &next.again);
                    push_record(false, s0, d0, el, dr, 2, &next.hard);
                    push_record(false, s0, d0, el, dr, 3, &next.good);
                    push_record(false, s0, d0, el, dr, 4, &next.easy);
                }
            }
        }
    }

    let doc = json!({
        "generator": "fsrs crate (Rust)",
        "fsrs_version": env!("CARGO_PKG_VERSION"),
        "vectors": out,
    });

    println!("{}", serde_json::to_string_pretty(&doc).unwrap());
}
