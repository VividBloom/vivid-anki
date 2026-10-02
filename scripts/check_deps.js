const fs = require('fs');
const path = require('path');

const SKIP_DIRS = new Set(['entryability', 'resources', 'test']);
const LAYERS = {
    'common': 0,
    'data': 1,
    'domain': 2,
    'ui': 3
};

const IMPORT_RE = /import\s+(?:\{[^}]*\}|\w+)\s+from\s+['"]([^'"]+)['"]/g;

function layerOf(relPath) {
    const parts = relPath.split(path.sep);
    for (const p of parts) {
        if (p in LAYERS) return p;
    }
    return null;
}

function resolvePath(curDir, spec) {
    if (!spec.startsWith('.')) return null;
    return path.normalize(path.join(curDir, spec));
}

function main() {
    const strict = process.argv.includes('--strict');
    const root = path.resolve(__dirname, '..', 'entry', 'src', 'main', 'ets');
    
    if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
        console.log('找不到源码目录：' + root);
        return 2;
    }

    const files = [];
    function walk(dir) {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            if (entry.isDirectory()) {
                if (!SKIP_DIRS.has(entry.name)) {
                    walk(path.join(dir, entry.name));
                }
            } else if (entry.isFile() && entry.name.endsWith('.ets')) {
                const fullPath = path.join(dir, entry.name);
                files.push(fullPath);
            }
        }
    }
    walk(root);

    const edges = {};
    const problems = [];

    for (const f of files) {
        const rel = path.relative(root, f);
        const curLayer = layerOf(rel);
        const curDir = path.dirname(f);
        
        let src;
        try {
            src = fs.readFileSync(f, 'utf-8');
        } catch (e) {
            continue;
        }

        let m;
        while ((m = IMPORT_RE.exec(src)) !== null) {
            const spec = m[1];
            let tgt = resolvePath(curDir, spec);
            if (!tgt) continue;

            let found = false;
            for (const cand of [tgt + '.ets', path.join(tgt, 'index.ets')]) {
                if (fs.existsSync(cand)) {
                    tgt = cand;
                    found = true;
                    break;
                }
            }
            if (!found) continue;

            const tgtRel = path.relative(root, tgt);
            const tgtLayer = layerOf(tgtRel);
            
            if (!tgtLayer || !curLayer) continue;

            if (!edges[curLayer]) edges[curLayer] = new Set();
            edges[curLayer].add(tgtLayer);

            if (LAYERS[tgtLayer] > LAYERS[curLayer]) {
                problems.push(`反向依赖  ${rel}(${curLayer}) → ${tgtRel}(${tgtLayer})`);
            }

            if (curLayer === 'ui' && tgtLayer === 'data') {
                problems.push(`跨层依赖  ${rel}(ui) → ${tgtRel}(data)，应改为依赖 domain`);
            }

            if (curLayer === 'common' && tgtLayer !== 'common') {
                problems.push(`common 层不得依赖上层  ${rel} → ${tgtRel}`);
            }
        }
    }

    for (const a in LAYERS) {
        for (const b in LAYERS) {
            if (a !== b && edges[a] && edges[a].has(b) && edges[b] && edges[b].has(a)) {
                if (LAYERS[a] < LAYERS[b]) {
                    problems.push(`循环依赖  ${a} ⇄ ${b}`);
                }
            }
        }
    }

    console.log('='.repeat(56));
    console.log(`依赖方向检查（${files.length} 个 .ets 文件）`);
    console.log('='.repeat(56));
    console.log('\n允许方向：ui → domain → data → common\n');
    console.log('实际引用关系：');
    
    const sortedLayers = Object.keys(LAYERS).sort((a, b) => LAYERS[a] - LAYERS[b]);
    for (const a of sortedLayers) {
        const deps = edges[a] ? Array.from(edges[a]).sort((x, y) => LAYERS[x] - LAYERS[y]) : [];
        console.log(`  ${a.padEnd(8)} → ${deps.length ? deps.join(', ') : '（无）'}`);
    }

    console.log();
    if (problems.length > 0) {
        const seen = [...new Set(problems)];
        console.log(`发现 ${seen.length} 处问题：`);
        for (const p of seen) {
            console.log('  ✗ ' + p);
        }
        console.log();
        if (strict) {
            process.exit(1);
        }
    } else {
        console.log('✓ 依赖方向全部合规');
    }
    process.exit(0);
}

main();