/* =========================================================
   瞄一眼 · 可交互原型
   ========================================================= */

/* ---------------- 图标 ---------------- */
const ICONS = {
  flame:'<path d="M12 3c2.6 3.1 5.2 5 5.2 8.5a5.2 5.2 0 0 1-10.4.3c0-1.3.4-2.5 1.2-3.6-1.3 1-1.8 2.2-1.8 3.6 0 3.6 2.9 6.4 6.5 6.4s6.5-2.8 6.5-6.4c0-3.9-3.6-6.1-7.2-8.8z" fill="currentColor"/>',
  check:'<path d="M4 12.5l5.2 5.2L20.5 6.4" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"/>',
  camera:'<rect x="2.6" y="7.2" width="18.8" height="13.2" rx="3" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M8.6 7.2l1.3-2.4h4.2l1.3 2.4" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/><circle cx="12" cy="13.6" r="3.6" fill="none" stroke="currentColor" stroke-width="1.9"/>',
  mic:'<rect x="9" y="2.8" width="6" height="11" rx="3" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M5.4 11.4a6.6 6.6 0 0 0 13.2 0" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M12 18v3.2M8.4 21.2h7.2" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  image:'<rect x="3" y="4.6" width="18" height="14.8" rx="2.6" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M3.4 17l4.8-4.8 3.6 3.6 3.1-3.1 5.7 5.7" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><circle cx="8.2" cy="9" r="1.7" fill="currentColor"/>',
  search:'<circle cx="10.6" cy="10.6" r="6.6" fill="none" stroke="currentColor" stroke-width="2"/><path d="M15.6 15.6l5 5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  plus:'<path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/>',
  edit:'<path d="M4 20h4.2L20.2 8 16 3.8 4 15.8z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M14.4 5.6l4.2 4.2" fill="none" stroke="currentColor" stroke-width="1.8"/>',
  close:'<path d="M6 6l12 12M18 6L6 18" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/>',
  doc:'<path d="M6 2.8h7.6L18.4 7.6V21.2H6z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M13.6 2.8v4.8h4.8" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M8.8 12.4h6.4M8.8 16.2h6.4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  paste:'<path d="M9 3.4h6v3H9z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M5 5.6h3v2.6H5.6A1.7 1.7 0 0 0 3.9 10v9.4a1.7 1.7 0 0 0 1.7 1.7h13a1.7 1.7 0 0 0 1.7-1.7V10a1.7 1.7 0 0 0-1.7-1.7H16V5.6h3" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M7.8 13.4h8.4M7.8 17h5" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  bell:'<path d="M12 3.4a5.8 5.8 0 0 1 5.8 5.8c0 4.2 1.6 5.8 1.6 5.8H4.6s1.6-1.6 1.6-5.8A5.8 5.8 0 0 1 12 3.4z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M10 19.2a2.1 2.1 0 0 0 4 0" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
  chart:'<path d="M4 20.4V10.6M10 20.4V3.6M16 20.4v-7.4M22 20.4H2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  user:'<circle cx="12" cy="8.2" r="4.1" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M4.4 20.6c1.3-4 4.1-6.1 7.6-6.1s6.3 2.1 7.6 6.1" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
  home:'<path d="M3.4 10.8L12 3.4l8.6 7.4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M6.2 9.4V20.6h11.6V9.4" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M9.8 20.6v-5.6h4.4v5.6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  cards:'<rect x="3" y="6.6" width="11.6" height="12" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M8.6 3.6h11.6v12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  back:'<path d="M15 4.6L7.6 12l7.4 7.4" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>',
  more:'<circle cx="12" cy="5.4" r="1.85" fill="currentColor"/><circle cx="12" cy="12" r="1.85" fill="currentColor"/><circle cx="12" cy="18.6" r="1.85" fill="currentColor"/>',
  shield:'<path d="M12 3.2l7.2 3v6.2c0 4.6-3.1 7.7-7.2 9.2-4.1-1.5-7.2-4.6-7.2-9.2V6.2z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M8.7 12.1l2.5 2.5 4.1-4.5" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>',
  clock:'<circle cx="12" cy="12" r="8.6" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M12 6.8v5.5l3.5 2.1" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>',
  arrowR:'<path d="M9.2 4.8l7.2 7.2-7.2 7.2" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
  chevD:'<path d="M5 8.6l7 7 7-7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
  chevU:'<path d="M5 15.4l7-7 7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
  star:'<path d="M12 3.4l2.7 5.6 6.1.9-4.4 4.3 1 6.1-5.4-3-5.4 3 1-6.1-4.4-4.3 6.1-.9z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  download:'<path d="M12 3.6v10.8" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M7.4 10.4L12 15l4.6-4.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/><path d="M4.4 19.6h15.2" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  sparkle:'<path d="M12 2.6l1.9 5.5 5.5 1.9-5.5 1.9L12 17.4l-1.9-5.5-5.5-1.9 5.5-1.9z" fill="currentColor"/><path d="M18.6 15l.9 2.4 2.4.9-2.4.9-.9 2.4-.9-2.4-2.4-.9 2.4-.9z" fill="currentColor"/>',
  settings:'<circle cx="12" cy="12" r="3.2" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M19.4 14.2a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1v.3a2 2 0 1 1-4 0v-.2a1.6 1.6 0 0 0-2.8-1.1l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0-1.1-2.7H3a2 2 0 1 1 0-4h.2a1.6 1.6 0 0 0 1.1-2.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3h.1a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.2a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0 1.1 2.7h.3a2 2 0 1 1 0 4h-.2a1.6 1.6 0 0 0-1.5 1z" fill="none" stroke="currentColor" stroke-width="1.6"/>',
  cloud:'<path d="M7.2 18.4h10a3.9 3.9 0 0 0 .4-7.8 5.4 5.4 0 0 0-10.4-1.4 4.3 4.3 0 0 0 0 9.2z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  layers:'<path d="M12 3.2l8.4 4.4-8.4 4.4L3.6 7.6z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M3.6 12.4l8.4 4.4 8.4-4.4M3.6 16.8l8.4 4.4 8.4-4.4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',

  /* --- 新增：异常 / 权限 / 数据 --- */
  alert:'<path d="M12 3.4L21.4 19.6H2.6z" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/><path d="M12 9.4v4.6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="16.8" r="1.15" fill="currentColor"/>',
  xcircle:'<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M8.6 8.6l6.8 6.8M15.4 8.6l-6.8 6.8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  checkcircle:'<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M7.8 12.2l2.9 2.9 5.5-5.8" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>',
  info:'<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M12 11v5.4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="7.8" r="1.15" fill="currentColor"/>',
  wifioff:'<path d="M2 8.5a15 15 0 0 1 6.6-3.6M15.6 5.2A15 15 0 0 1 22 8.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M5.5 12.5a10 10 0 0 1 4-2.3M14.6 10.4a10 10 0 0 1 4 2.1" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M9 16.5a5 5 0 0 1 6 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="20" r="1.4" fill="currentColor"/><path d="M3 3l18 18" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"/>',
  refresh:'<path d="M20.4 12a8.4 8.4 0 1 1-2.5-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M20.6 4.4v5h-5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  folder:'<path d="M3.4 6.4a2 2 0 0 1 2-2h4l2 2.6h7.2a2 2 0 0 1 2 2v9.6a2 2 0 0 1-2 2H5.4a2 2 0 0 1-2-2z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  trash:'<path d="M4.6 6.6h14.8M9.4 6.6V4.4h5.2v2.2M6.6 6.6l1 13.2h8.8l1-13.2" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M10.2 10.4v6M13.8 10.4v6" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  file:'<path d="M6 2.8h8l4.4 4.4v14H6z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M14 2.8v4.4h4.4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  upload:'<path d="M12 16.4V5.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M7.4 10.2L12 5.6l4.6 4.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/><path d="M4.4 19.6h15.2" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  external:'<path d="M14 4.4h5.6V10" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/><path d="M19.6 4.4L11 13" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M17.4 14v5.6H4.4V6.6H10" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>',
  lock:'<rect x="4.6" y="10.4" width="14.8" height="9.6" rx="2.2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M8 10.4V7.8a4 4 0 0 1 8 0v2.6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
  eye:'<path d="M2.4 12S6 5.6 12 5.6 21.6 12 21.6 12 18 18.4 12 18.4 2.4 12 2.4 12z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="1.8"/>',
  pause:'<rect x="7" y="5" width="3.6" height="14" rx="1.4" fill="currentColor"/><rect x="13.4" y="5" width="3.6" height="14" rx="1.4" fill="currentColor"/>',
  inbox:'<path d="M3.4 13.4h4.2l1.4 2.6h6l1.4-2.6h4.2" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M5.6 4.6h12.8l2 8.8v4.4a2 2 0 0 1-2 2H5.6a2 2 0 0 1-2-2v-4.4z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',

  /* --- 新增：中断恢复 / 编辑 / 接续 / 实况窗 --- */
  restore:'<path d="M4.4 12a7.6 7.6 0 1 0 2.3-5.4" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M4.2 4.6v4.9h4.9" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/><path d="M19.8 12a7.6 7.6 0 0 1-12.9 5.4" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  undo:'<path d="M4.4 9.6h9.2a5.2 5.2 0 0 1 0 10.4H8.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/><path d="M8 5.2L3.8 9.6 8 14" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>',
  smartphone:'<rect x="6.4" y="2.4" width="11.2" height="19.2" rx="2.6" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M10.4 5.2h3.2" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><circle cx="12" cy="18.4" r="1.1" fill="currentColor"/>',
  tablet:'<rect x="4" y="3.4" width="16" height="17.2" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M9.6 17.8h4.8" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  share:'<circle cx="17.6" cy="5.6" r="2.6" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="6.4" cy="12" r="2.6" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="17.6" cy="18.4" r="2.6" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M15.4 6.8L8.6 10.8M8.6 13.2l6.8 4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
  message:'<path d="M20.4 12.4c0 4-3.8 7.2-8.4 7.2a9.7 9.7 0 0 1-2.6-.35L4.4 21l1.2-3.6a6.9 6.9 0 0 1-2-4.9c0-4 3.8-7.2 8.4-7.2s8.4 3.2 8.4 7.1z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  help:'<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M9.6 9.4a2.5 2.5 0 1 1 3.4 2.3c-.7.3-1 .9-1 1.6v.4" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><circle cx="12" cy="17" r="1.1" fill="currentColor"/>',
  mail:'<rect x="2.8" y="5" width="18.4" height="14" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M3.4 6.6L12 13l8.6-6.4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  heart:'<path d="M12 20.4S3.6 15.2 3.6 9.6a4.6 4.6 0 0 1 8.4-2.6 4.6 4.6 0 0 1 8.4 2.6c0 5.6-8.4 10.8-8.4 10.8z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
  play:'<path d="M8 5.4l11 6.6-11 6.6z" fill="currentColor"/>',
  handoff:'<path d="M8.4 14.6l3 3 6.4-6.4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M4 12a8 8 0 0 1 8-8M20 12a8 8 0 0 1-8 8" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
};
function ic(name, size=22, cls=''){
  return `<svg class="${cls}" viewBox="0 0 24 24" width="${size}" height="${size}">${ICONS[name]||''}</svg>`;
}

/* ---------------- 全局状态 ---------------- */
const S = {
  screen: 'home',
  /** 删除确认针对的对象：'deck' | 'card' */
  delKind: 'deck',
  dark: false,
  plan: null,              // 每日时长档位
  queue: 12,               // 今日剩余
  total: 12,
  flipped: false,          // 是否已翻卡
  aiSel: [true, true, false],
  cardType: 0,
  todayDone: false,
  streak: 3,
};

/* ---------------- 页面元数据 ---------------- */
const META = {
  onb1:{ pid:'P01-1', name:'引导① 选个起点' },
  onb2:{ pid:'P01-2', name:'引导② 丢进内容' },
  onb3:{ pid:'P01-3', name:'引导③ 定个时间' },
  onb4:{ pid:'P01-4', name:'引导④ 讲清原理' },
  home:{ pid:'P02',  name:'今天（首页）' },
  homeDone:{ pid:'P02b', name:'今天（零复习态）' },
  review:{ pid:'P03', name:'复习页' },
  done:{ pid:'P04',  name:'复习结算' },
  create:{ pid:'P05', name:'制卡页' },
  aipreview:{ pid:'P06', name:'AI 卡片预览' },
  cards:{ pid:'P07', name:'卡片（内容管理）' },
  my:{ pid:'P08',  name:'我的（设置）' },
  stats:{ pid:'P09', name:'统计页' },
  back:{ pid:'P10', name:'回归引导' },
  widget:{ pid:'P12', name:'桌面服务卡片' },

  /* ===== 补充：空状态 / 错误态 / 权限 / 数据流程 ===== */
  emptyHome:{ pid:'P02c', name:'首页 · 全新用户空态' },
  emptyCards:{ pid:'P07b', name:'卡片页 · 空态' },
  emptySearch:{ pid:'P07c', name:'搜索无结果' },
  errAi:{ pid:'P06b', name:'AI 生成失败' },
  errImport:{ pid:'P11b', name:'导入失败' },
  offline:{ pid:'ERR',  name:'无网络 · AI 不可用' },
  permNotify:{ pid:'PERM', name:'通知权限申请' },
  permCamera:{ pid:'PERM', name:'相机权限申请' },
  permDenied:{ pid:'PERM', name:'权限被拒 · 引导开启' },
  importPage:{ pid:'P11',  name:'导入牌组' },
  importing:{ pid:'P11c', name:'导入进行中' },
  importOk:{ pid:'P11d', name:'导入完成' },
  deck:{ pid:'P07d', name:'牌组详情' },
  reminder:{ pid:'P08b', name:'提醒设置' },

  /* ===== 补充：中断恢复 / 编辑 / 多端 / 实况窗 ===== */
  resume:{ pid:'P03b', name:'复习中断恢复' },
  undo:{ pid:'P03c', name:'撤销评分反馈' },
  cardEdit:{ pid:'P05b', name:'卡片编辑页' },
  about:{ pid:'P08c', name:'关于与反馈' },
  handoff:{ pid:'P13',  name:'多端接续提示' },
  liveWindow:{ pid:'P14', name:'实况窗 / 锁屏进度' },
  settings:{ pid:'P08d', name:'偏好设置' },
  exportPage:{ pid:'P11e', name:'导出与备份' },
  tablet:{ pid:'P15',  name:'平板 / 折叠屏布局' },
  aiLoading:{ pid:'P06c', name:'AI 生成中（加载态）' },
  skeleton:{ pid:'P02d', name:'首页骨架屏（加载态）' },

  /* ===== 补充：回收站（N-01「30 天可恢复」的产品层落地） ===== */
  trash:{ pid:'P16',  name:'回收站' },
  trashEmpty:{ pid:'P16b', name:'回收站 · 空态' },
  deleteConfirm:{ pid:'P16c', name:'删除确认（移入回收站）' },
};

/* 右侧面板分组，避免 28 屏挤成一团 */
const GROUPS = [
  { title:'主流程', ids:['onb1','onb2','onb3','onb4','home','homeDone','review','done','create','aipreview','cards','my','stats','back','widget'] },
  { title:'空状态', ids:['emptyHome','emptyCards','emptySearch'] },
  { title:'加载中', ids:['aiLoading','skeleton'] },
  { title:'错误与异常', ids:['errAi','errImport','offline'] },
  { title:'权限申请', ids:['permNotify','permCamera','permDenied'] },
  { title:'数据流程', ids:['importPage','importing','importOk','deck','reminder'] },
  { title:'进阶场景', ids:['resume','undo','cardEdit','about','settings','exportPage','handoff','liveWindow','tablet'] },
  { title:'回收站', ids:['trash','trashEmpty','deleteConfirm'] },
];

const NOTES = {
  onb1:[
    '<b>先给内容，再给工具。</b>首屏不是空白页，而是 3 个精品牌组 + 「我自己有内容」。',
    '解决新手第一道障碍：<b>「我该记什么？」</b>',
    '任一选项都能立即进入复习，不需要先建牌组、选笔记类型。',
  ],
  onb2:[
    '<b>让用户在第一分钟就体验到「我居然已经有卡了」。</b>',
    '三个入口：拍照 / 粘贴 / 导入文档，覆盖主要素材来源。',
    'AI 只做<b>提取式</b>拆分，不编造内容，且结果可逐张修改。',
  ],
  onb3:[
    '<b>全产品唯一强制询问的设置项。</b>其余全部给默认值。',
    '副文案「随时可以改」消除选择焦虑。',
    '系统据此推算每日新卡与复习上限（5/15/30 分钟 → 约 15/40/80 张）。',
  ],
  onb4:[
    '<b>主动解释「为什么今天只有 12 张」</b>，而不是让用户自己猜。',
    '这是新手第二大困惑点，不解释就会被误认为「功能少」。',
    '落点文案：<b>「这不是少，是刚刚好。」</b>',
  ],
  home:[
    '<b>打开即复习。</b>首页不叫「牌组列表」而叫「今天」。',
    '主卡展示「还有 12 张 · 约 5 分钟」，配一个巨大的开始按钮。',
    '<b>永不显示逾期总量</b>——积压数字是新手弃坑的头号杀手。',
    '连续天数是全页唯一强调的数字，其余统计都是次要信息。',
  ],
  homeDone:[
    '零复习态<b>不能是空白页</b>，否则用户不知道是「完成」还是「出错了」。',
    '明确告知「今天已全部完成」+ 用时，给正向反馈。',
    '同时预告明天的量，降低第二天的心理负担。',
  ],
  review:[
    '<b>全屏一张卡</b>，问题居中、字号放大，占满视野。',
    '进度条文案是「还剩 8 张」而非「已完成 4/12」，降低压迫感。',
    '四档按钮<b>全部正向措辞</b>：再来一次 / 有点难 / 记得 / 太简单。',
    '禁用「忘记」「错误」等负面词，避免挫败感。',
  ],
  done:[
    '<b>不展示错误率</b>。结算页只给正向反馈与明天的预告。',
    '连续天数、明日量两个信息，为次日回来埋钩子。',
  ],
  create:[
    '<b>单页输入，不要求先建牌组。</b>这是与 Anki 最大的流程差异。',
    '高级选项（填空卡 / 双向卡）收在「更多选项」，前两周不暴露。',
    '粘贴多行文本可自动拆成多张，降低批量制卡成本。',
  ],
  aipreview:[
    '<span class="warnx"><b>强制草稿制：不确认不入库。</b></span>',
    '错卡混入复习流会瞬间摧毁信任，且极难挽回。',
    '顶部常驻警示条，每张卡可勾选 / 编辑 / 删除。',
    '埋点关注 kept_count / generated_count，低于 60% 说明生成质量不合格。',
  ],
  cards:[
    '牌组为<b>扁平结构，不支持嵌套</b>——层级管理是新手的负担。',
    '每个牌组显示今日待复习量，而不是总卡片数。',
    '右下角悬浮加号是制卡主入口。',
  ],
  my:[
    '设置项刻意做少，只有必要项。',
    '<b>导出永久免费、永不设限</b>——数据可迁移是信任基础。',
    '账号仅用于云同步与 AI 额度，不注册也能完整使用。',
  ],
  stats:[
    '<b>只放四项</b>：连续天数、完成率、未来 7 天预测、热力图。',
    '刻意不做留存率曲线、记忆矩阵——那是老用户的玩具。',
    '「未来 7 天预测」让用户提前知道明天会不会被淹。',
  ],
  back:[
    '<b>断卡 ≥3 天触发，分 3 天平滑消化。</b>',
    '明确写出「不催你，也不显示积压数字」。',
    '提供「明天再开始」的退路，不强迫。',
    '单次会话 >25 分钟会主动提示休息。',
  ],
  widget:[
    '<b>留存利器。</b>把「找 App → 打开 → 点牌组」压缩成「看桌面 → 点一下」。',
    '显示今日剩余量 + 完成进度环，点击直达复习页。',
    '这是鸿蒙相对其他平台的结构性优势，V1.0 优先级最高。',
  ],

  /* ===== 补充页面说明 ===== */
  emptyHome:[
    '这是比「零复习态」<b>更早</b>的状态 —— 用户一张卡都还没有。',
    '绝不能是空白页，必须同时给出三条开始路径（手动 / AI / 导入）。',
    '文案要传递「很容易开始」，而不是「你还没有内容」。',
    '<b>首屏体验决定 7 日留存</b>，这一屏值得单独打磨。',
  ],
  emptyCards:[
    '每个列表页都必须有空态，否则用户会以为是加载失败。',
    '给出「新建」和「导入」两个出口，覆盖两种用户意图。',
  ],
  emptySearch:[
    '搜索无结果要<b>保留关键词</b>并给出建议，而不是只说「无结果」。',
    '提供「新建这张卡」的出口 —— 搜不到往往正是用户想创建它的信号。',
  ],
  errAi:[
    '<b>失败不扣额度、不丢用户输入</b>，这是底线。',
    '必须给出「改为手动制卡」的退路，不让用户卡死。',
    '展示失败明细（输入长度、处理方式）便于用户判断和反馈。',
    '埋点监控失败率；连续失败时应自动降级为手动模式。',
  ],
  errImport:[
    '明确告知<b>「原始文件没有被修改」</b>，消除用户最大的顾虑。',
    '给出具体的失败原因（如缺少 collection 表），而不是笼统的「导入失败」。',
    '同时列出支持的格式，让用户知道下一步该怎么做。',
  ],
  offline:[
    '<b>离线优先</b>：核心复习功能永远可用，这是本产品的定位承诺。',
    '断网时<b>明确列出哪些能用、哪些不能</b>，不让用户自己试出来。',
    '给出「改用手动制卡」的替代路径。',
  ],
  permNotify:[
    '<b>本页刻意不画系统授权弹窗。</b>PUBLISH_AGENT_REMINDER 属 system_grant，安装即授予，点「开启提醒」后直接生效 —— 画一个「想发送通知」的弹窗会与真实行为不符。',
    '底部改为说明<b>唯一需要用户手动处理的情况</b>：在系统设置里关掉了本应用的通知。',

    '采用<b>「前置说明 + 系统弹窗」</b>两段式，显著提升授权率。',
    '先讲清价值（一天一次、文案温和、随时可关），再弹系统框。',
    '前置说明页是<b>自定义页面</b>，可以反复改文案做 A/B。',
    '「暂时不用」的按钮样式要弱于主按钮，但不隐藏。',
  ],
  permCamera:[
    '强调<b>「照片只在设备上处理」</b>，直接回应隐私顾虑。',
    '说明「只在你主动拍照时调用」，消除后台偷拍的担忧。',
    '「不授权也能用」降低拒绝的心理成本 —— 反而更容易被接受。',
  ],
  permDenied:[
    '<b>被拒后不再反复弹窗</b>，这是尊重用户的选择。',
    '明确区分「影响什么」和「不影响什么」，避免用户以为 App 坏了。',
    '给一条无负担的退路（「先不用，直接开始」）。',
    '提醒是留存手段，但<b>不能用骚扰换开启率</b>。',
  ],
  importPage:[
    '.apkg 导入是<b>最便宜的冷启动渠道</b>，必须做扎实。',
    '明确告知「导入后不会立刻全部开刷」，管理预期。',
    '列出最近文件，减少重复操作。',
  ],
  importing:[
    '<b>分步骤可见的进度</b>比一个转圈更能建立信任。',
    '明确提示「不要关闭应用」，避免中断导致数据不一致。',
    '大文件导入需给出时间预期。',
  ],
  importOk:[
    '结果页<b>必须突出「已按每天 20 张分批安排」</b>。',
    '一次性导入几千张然后被淹没，是可预见的弃坑方式，必须在产品层拦住。',
    '同时告知跳过的卡片数（重复/损坏），保持透明。',
  ],
  deck:[
    '牌组详情只放新手看得懂的三件事：今日量、已掌握、状态分布。',
    '状态用「未学习 / 学习中 / 复习中」而非 Anki 的术语。',
    '删除操作需要二次确认，且明确告知会删除多少张卡片。',
  ],
  reminder:[
    '提供<b>提醒文案预览</b>，让用户提前知道会收到什么。',
    '明确列出反例文案，避免团队后来写出制造焦虑的推送。',
    '时间选项给常用档位 + 自定义，降低选择成本。',
  ],

  /* ===== 进阶场景说明 ===== */
  resume:[
    '中断恢复的关键是<b>让用户确信「已完成的部分没白做」</b>。',
    '明确告知保存到第几张、剩余多少、约需多久。',
    '因为评分是即时落盘的，中断不会丢数据、也不会重复计数。',
    '提供「今天先到这里」的退路 —— 有时用户就是被打断了。',
  ],
  undo:[
    '撤销必须能<b>回滚 Stability / Difficulty / due</b>，而不只是把卡片塞回队列。',
    'Snackbar 要说明恢复到什么状态，并给「重做」的反向出口。',
    '撤销是新手的安全网 —— 点错了不该有代价。',
    '注意：撤销需同步删除对应的 revlog 记录，否则会污染参数训练数据。',
  ],
  cardEdit:[
    '编辑页与制卡页的信息结构不同：<b>多了复习历史与危险操作</b>。',
    '删除 / 重置 / 暂停都需要二次确认。',
    '重置学习进度要说明后果（当作新卡重新开始）。',
    '这个页面是老用户高频使用的，新手前两周基本不会来。',
  ],
  about:[
    '写明<b>「自研 FSRS-6 + BSD-3 参数，未使用 rslib」</b>，规避协议疑问。',
    '展示算法说明能提升专业用户的信任度。',
    '反馈入口、评分入口、分享入口是冷启动期的三个关键动作。',
    '版本信息与数据统计便于用户反馈问题时描述环境。',
  ],
  handoff:[
    '<b>多端接续是鸿蒙的独占能力</b>，一次开发多端部署的直接红利。',
    '弹窗出现在<b>目标设备</b>（平板）上，而不是源设备。',
    '要显示源设备的进度，让用户知道「接到哪里」。',
    '「不用了」必须同样容易点 —— 不能做成强制接续。',
  ],
  liveWindow:[
    '<b>实况窗在锁屏与状态栏常驻</b>，不用解锁就能看到剩余量。',
    '胶囊形态用于极简展示，卡片形态展示更多信息与操作入口。',
    '碎片时间场景（通勤、排队）下这一屏的价值最高。',
    'PRD 中排在 V1.1，但效果值得提前验证。',
  ],

  settings:[
    '<b>这一页刻意只放 6 个开关。</b>Anki 有上百个选项，每多一个就多一次决策。',
    '目标留存率等 FSRS 参数默认隐藏，并明确标注「不建议调整」。',
    '开关项按「手势 / 显示 / 学习」分组，不按技术实现分组。',
    '新增任何设置项都要过审：新手会不会因此需要看教程？',
  ],
  exportPage:[
    '<b>导出永久免费、永不设限</b> —— 这是 PRD 里的 P6 原则。',
    '提供三种格式：.apkg（可导入 Anki）、.json（完整备份）、.csv（Excel 可读）。',
    '自动本地备份默认开启，每日本地快照保留 7 份。',
    '竞品曾在导出上做限制导致口碑翻车，这是本产品的差异化信任点。',
  ],
  tablet:[
    '<b>一次开发多端部署</b>：手机 / 折叠屏 / 平板同一套 ArkTS 代码。',
    '大屏下自动切换为<b>左侧牌组导航 + 右侧内容区</b>的双栏布局。',
    '卡片字号在大屏下更舒展，四档评分从 2×2 改为一行四个。',
    '这是鸿蒙相对安卓开发最实在的红利，值得在 V1.1 就支持。',
  ],
  trash:[
    '<b>「30 天可恢复」的产品层出口。</b>数据层已由 DeckLifecycleService 实现，但用户必须能找到恢复入口，否则该承诺不成立。',
    '顶部说明条主动讲清两件事：到期会自动清理，但<b>复习记录会保留</b> —— 后者直接呼应 revlog 不随卡片删除的设计。',
    '<b>不写「已逾期 / 即将过期」，只写「还剩 N 天」。</b>剩余 ≤7 天才换成提醒色，且用橙不用红，避免惩罚感。',
    '每条都给「恢复」与「彻底删除」两个动作，彻底删除是明确的用户决策，不做成静默过期。',
  ],
  trashEmpty:[
    '空态也要讲清机制：「删除的内容会先放到这里，30 天内随时可以找回来」。',
    '让用户在还没删东西时就建立安全感，这比事后解释有效得多。',
  ],
  deleteConfirm:[
    '<b>叠加在来源页之上的确认框</b>，用户能看清自己正在删什么。',
    '按钮文案是「移入回收站」而不是「删除」——同样是不制造焦虑的原则。',
    '明确写出「牌组内的 860 张卡片会一起移入」，避免用户以为只删了牌组、卡片还在。',
    '绿色提示条「复习记录不会丢失」：<b>这是本次修复最该让用户知道的一点</b>，消除「删了就白学了」的顾虑。',
  ],

};

/* 主流程（右侧快捷入口） */
const FLOW = ['onb1','onb2','onb3','onb4','home','review','done','create','aipreview','cards','my','stats','back','widget'];

/* ---------------- 工具 ---------------- */
function go(id){ S.screen = id; render(); }
function toast(msg){
  const t = document.getElementById('toast');
  t.textContent = msg; t.classList.add('show');
  clearTimeout(t._t); t._t = setTimeout(()=>t.classList.remove('show'), 1900);
}
function tab(active){
  const items = [['home','home','今天'],['cards','cards','卡片'],['my','user','我的']];
  return `<div class="tabbar">` + items.map(([id,icon,label])=>
    `<button class="${active===id?'on':''}" data-go="${id}">
       ${ic(icon,23)}<span>${label}</span>
     </button>`).join('') + `</div>`;
}

/* ---------------- 各页面渲染 ---------------- */
const PAGES = {};

/* ===== 引导 ①②③④ ===== */
PAGES.onb1 = () => `
<div class="progress-wrap" style="padding-top:58px">
  <div class="progress"><i style="width:25%"></i></div>
  <span class="step-txt">1 / 4</span>
</div>
<div class="body guide">
  <div style="display:flex;align-items:center;gap:9px;margin-bottom:14px">
    <img src="data:image/png;base64,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" style="width:34px;height:34px;border-radius:9px;display:block">
    <div>
      <div style="font-size:16px;font-weight:800;letter-spacing:.3px">瞄一眼</div>
      <div style="font-size:11px;color:var(--txt3);margin-top:1px">五分钟，把该记的记了</div>
    </div>
  </div>
  <h2>你想先<br>记住点什么？</h2>
  <div class="sub">选一个，马上就能开始背</div>
  ${[
    ['考研英语核心词','2400 张 · 已备好','var(--purple)','var(--purple-l)','star'],
    ['医学考点精选','1800 张 · 已备好','var(--orange)','var(--orange-l)','shield'],
    ['生活常用英语','900 张 · 已备好','var(--green)','var(--green-l)','sparkle'],
  ].map(([t,s,c,b,i])=>`
  <button class="opt" data-go="onb2">
    <div class="opt-ic" style="background:${b}">${ic(i,24)}</div>
    <div><div class="opt-t">${t}</div><div class="opt-s">${s}</div></div>
    <span class="opt-arrow" style="color:${c}">${ic('arrowR',20)}</span>
  </button>`).join('')}
  <button class="row" data-go="onb2" style="gap:6px;padding:8px 4px;color:var(--prim);font-weight:700;font-size:15.5px;margin-top:6px">
    我自己有内容 ${ic('arrowR',18)}
  </button>
</div>`;

PAGES.onb2 = () => `
<div class="progress-wrap" style="padding-top:58px">
  <div class="progress"><i style="width:50%"></i></div>
  <span class="step-txt">2 / 4</span>
</div>
<div class="body guide">
  <h2>把想记的东西<br>丢进来就行</h2>
  <div class="sub">拍照、粘贴、导入，都行</div>
  <div class="row" style="gap:11px;margin-bottom:16px">
    ${[['拍照','camera','var(--prim)','var(--prim-l)'],
       ['粘贴','paste','var(--purple)','var(--purple-l)'],
       ['文档','doc','var(--orange)','var(--orange-l)']].map(([t,i,c,b])=>`
    <button class="entry" style="flex:1" data-act="input">
      <div class="entry-ic" style="background:${b}">${ic(i,24)}</div>
      <div class="entry-t" style="color:${c}">${t}</div>
    </button>`).join('')}
  </div>
  <div class="inputbox">
    线粒体是细胞进行有氧呼吸的主要场所，被称为细胞的「动力工厂」。<br>
    叶绿体是植物细胞进行光合作用的场所，存在于绿色植物细胞中。
    <div class="tiny" style="margin-top:12px">已读取 2 段</div>
  </div>
  <div class="ai-chip">
    <div style="width:26px;height:26px;border-radius:8px;background:var(--green);display:grid;place-items:center;color:#fff;flex:0 0 auto">
      ${ic('check',15)}
    </div>
    <div><div class="n">帮你拆成 6 张？</div>
    <div class="d">已按知识点拆分，可以逐张修改</div></div>
  </div>
  <button class="btn green mt20" data-go="onb3">就用这 6 张</button>
</div>`;

PAGES.onb3 = () => `
<div class="progress-wrap" style="padding-top:58px">
  <div class="progress"><i style="width:75%"></i></div>
  <span class="step-txt">3 / 4</span>
</div>
<div class="body guide">
  <h2>每天大概<br>想花多久？</h2>
  <div class="sub">这是唯一需要你决定的设置</div>
  ${[['5 分钟','轻松','每天约 15 张'],
     ['15 分钟','标准','每天约 40 张'],
     ['30 分钟','冲刺','每天约 80 张']].map(([t,tag,s],i)=>`
  <button class="plan ${S.plan===i?'on':''}" data-act="plan" data-v="${i}">
    <div>
      <div class="plan-t">${t}</div>
      <div class="plan-s">${s}</div>
    </div>
    <span class="plan-badge" style="margin-left:auto">${tag}</span>
    ${S.plan===i?`<span style="margin-left:12px;color:var(--prim)">${ic('check',22)}</span>`:''}
  </button>`).join('')}
  <div class="tiny" style="text-align:center;margin-top:14px">随时可以在设置里改，不用担心选错</div>
  <button class="btn mt16" data-go="onb4" style="${S.plan===null?'opacity:.45':''}">下一步</button>
</div>`;

PAGES.onb4 = () => {
  // 遗忘曲线 SVG
  const W=300,H=120,pad=6;
  const pts=[]; for(let i=0;i<=60;i++){const t=i/60;
    const x=pad+t*(W-2*pad);
    const y=pad+(1-Math.exp(-3.4*t))/(1-Math.exp(-3.4))*(H-2*pad-16);
    pts.push([x,y]);}
  const d='M'+pts.map(p=>`${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' L');
  const marks=[0.16,0.40,0.66,0.88].map(t=>{
    const x=pad+t*(W-2*pad);
    const y=pad+(1-Math.exp(-3.4*t))/(1-Math.exp(-3.4))*(H-2*pad-16);
    return `<line x1="${x.toFixed(1)}" y1="${y.toFixed(1)}" x2="${x.toFixed(1)}" y2="${H-pad-16}" stroke="var(--prim)" stroke-width="1.3" stroke-dasharray="3 3"/>
            <circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="4.6" fill="var(--card)" stroke="var(--prim)" stroke-width="2.4"/>`;
  }).join('');
  return `
<div class="progress-wrap" style="padding-top:58px">
  <div class="progress"><i style="width:100%"></i></div>
  <span class="step-txt">4 / 4</span>
</div>
<div class="body guide">
  <h2>为什么今天<br>只有 12 张？</h2>
  <div class="curve">
    <div style="font-size:13px;color:var(--txt2);font-weight:700;margin-bottom:10px">记忆留存</div>
    <svg viewBox="0 0 ${W} ${H}" style="width:100%;height:120px">
      ${marks}
      <path d="${d}" fill="none" stroke="var(--prim)" stroke-width="2.7" stroke-linecap="round"/>
    </svg>
    <div class="legend"><span>第 1 天</span><span>第 30 天</span></div>
  </div>
  <div class="explain">
    刚记的东西忘得快；<br>
    在快忘的时候复习一次，<br>
    就记得更久一点。
  </div>
  <div class="callout">所以今天只给你 12 张 ——<br>这不是少，是刚刚好。</div>
  <button class="btn mt20" data-go="review">开始复习</button>
</div>`;
};

/* ===== 首页 ===== */
function homeBody(done){
  const heat=[3,1,0,2,4,3,0,1,4,2,3,3,1,0,2,4,4,1,3,2,0,4,3,1,2,4,0,3];
  const cols=['#EDF1F5','#C6E0FF','#7FB8FF','#3395FF','#0B5CD8'];
  const dcols=['#2A2E35','#16416F','#1D5FA8','#2E86E0','#5AA9F5'];
  const pal = S.dark?dcols:cols;
  const vals=[12,9,15,8,11,6,13], mx=Math.max(...vals);
  return `
<div class="navbar"><h1>今天</h1><div class="spacer"></div>
  <button class="icon-btn" data-act="noop" style="color:var(--txt2)">${ic('bell',22)}</button>
</div>
<div class="body haspad">
  <div class="tiny" style="margin-bottom:12px">9 月 15 日 星期二</div>
  <div class="hero ${done?'done':''}">
    ${done?`
      <div style="display:grid;place-items:center;margin:8px 0 18px">
        <div style="width:76px;height:76px;border-radius:50%;background:rgba(255,255,255,.18);display:grid;place-items:center">
          ${ic('check',40)}
        </div>
      </div>
      <div style="text-align:center;font-size:21px;font-weight:800">今天已全部完成</div>
      <div style="text-align:center;color:#D6F5E8;font-size:13.5px;margin-top:6px">12 张 · 用时 4 分 32 秒</div>
    `:`
      <div class="lbl">还有</div>
      <div class="num">${S.queue}<small>张</small></div>
      <div class="dur">约 ${Math.max(1,Math.round(S.queue*0.4))} 分钟</div>
      <button class="btn-white" data-go="review">开始复习</button>
    `}
  </div>

  <div class="stat2">
    <div class="stat">
      <div class="row" style="gap:5px;color:var(--orange)">${ic('flame',22)}</div>
      <div class="v">${S.streak}<small>天</small></div>
      <div class="k">连续打卡</div>
      <div class="x">本周已学 5 天</div>
    </div>
    <div class="stat">
      <div class="v" style="color:var(--green)">86<small>%</small></div>
      <div class="k">本月完成率</div>
      <div class="x">已复习 412 张</div>
    </div>
  </div>

  <div class="card">
    <div class="between"><b style="font-size:14px">本月</b><span class="tiny">15 天在学</span></div>
    <div class="heatgrid">${heat.map(v=>`<i style="background:${pal[v]}"></i>`).join('')}</div>
  </div>

  <div class="card mt12">
    <div class="between"><b style="font-size:14px">未来 7 天</b><span class="tiny">共约 74 张</span></div>
    <div class="forecast">
      ${vals.map((v,i)=>`
      <div class="fc ${i===2?'hi':''}">
        <span style="font-size:10.5px;color:${i===2?'var(--prim)':'var(--txt2)'};font-weight:700">${v}</span>
        <i style="height:${Math.max(6,46*v/mx)}px"></i>
        <span>${'一二三四五六日'[i]}</span>
      </div>`).join('')}
    </div>
  </div>
</div>
${tab('home')}`;
}
PAGES.home = () => homeBody(false);
PAGES.homeDone = () => homeBody(true);

/* ===== 复习页 ===== */
PAGES.review = () => {
  const doneN = S.total - S.queue;
  const pct = Math.round(doneN/S.total*100);
  const Q = {
    cat:'生物学',
    q:'细胞中被称为「动力工厂」、是有氧呼吸主要场所的细胞器是什么？',
    hint:'提示：它的名字里有「体」字',
    a:'线粒体', aEn:'Mitochondrion',
    ax:'双层膜结构，内含少量 DNA，能独立完成部分蛋白质合成。'
  };
  return `
<div class="review-pad">
  <div class="rv-top">
    <div class="rv-bar"><i style="width:${pct}%"></i></div>
    <span class="rv-count">还剩 ${S.queue} 张</span>
    <button class="icon-btn" data-act="noop" style="color:var(--txt2);width:28px">${ic('more',20)}</button>
  </div>

  ${S.flipped ? `
  <div class="qcard answered" data-act="flip">
    <div class="qcat" style="color:var(--txt3)">${Q.cat}</div>
    <div style="font-size:16px;color:var(--txt2);line-height:1.6">${Q.q}</div>
    <div class="answer">${Q.a}</div>
    <div class="answer-en">${Q.aEn}</div>
    <div class="answer-x">${Q.ax}</div>
    <div style="margin-top:auto"></div>
  </div>
  <div class="rate">
    <button class="rb1" data-act="rate" data-v="1"><span>再来一次</span></button>
    <button class="rb2" data-act="rate" data-v="2"><span>有点难</span></button>
    <button class="rb3" data-act="rate" data-v="3"><span>记得</span></button>
    <button class="rb4" data-act="rate" data-v="4"><span>太简单</span></button>
  </div>
  <div class="next-preview">下次再见它：3 天后</div>
  ` : `
  <div class="qcard" data-act="flip">
    <div class="qcat">${Q.cat}</div>
    <div class="qtext">${Q.q}</div>
    <div class="qhint">${Q.hint}</div>
    <div class="swipe-hint">
      上滑查看答案
      <svg class="chev" viewBox="0 0 24 24"><path d="M5 15l7-7 7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>
    </div>
  </div>
  <button class="btn gray sm mt12" data-act="skip">稍后再说</button>
  `}

  <div style="margin-top:14px;padding-top:12px;border-top:1px dashed var(--div)">
    <div class="tiny" style="text-align:center;margin-bottom:8px">异常流程演示</div>
    <div class="row" style="gap:8px">
      <button class="btn ghost sm" data-go="resume" style="flex:1;font-size:12.5px;padding:10px">中断恢复</button>
      <button class="btn ghost sm" data-go="undo" style="flex:1;font-size:12.5px;padding:10px">撤销反馈</button>
    </div>
  </div>
</div>`;
};

/* ===== 结算 ===== */
PAGES.done = () => `
<div class="done-wrap">
  <div class="done-ring"><i style="color:#fff">${ic('check',44)}</i></div>
  <div class="done-t1">今天完成了</div>
  <div class="done-t2">${S.total} 张</div>
  <div class="done-t3">用时 4 分 32 秒</div>
  <div class="done-cards">
    <div class="card row" style="gap:14px">
      <div style="color:var(--orange)">${ic('flame',26)}</div>
      <div><div style="font-size:16px;font-weight:700">连续 ${S.streak} 天</div>
      <div class="tiny" style="margin-top:3px">再坚持 4 天就能解锁新徽章</div></div>
    </div>
    <div class="card row mt12" style="gap:14px">
      <div style="color:var(--prim)">${ic('clock',26)}</div>
      <div><div style="font-size:16px;font-weight:700">明天约有 9 张</div>
      <div class="tiny" style="margin-top:3px">明天 20:00 提醒你</div></div>
    </div>
  </div>
</div>
<div style="padding:0 22px 30px">
  <button class="btn" data-go="homeDone">明天见</button>
</div>`;

/* ===== 制卡 ===== */
PAGES.create = () => `
<div class="navbar">
  <button class="icon-btn" data-go="cards" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:22px">做一张新卡</h1>
  <div class="spacer"></div>
  <button class="action" data-act="save">保存</button>
</div>
<div class="body">
  <div class="field-t">正面</div>
  <div class="field">
    <textarea rows="3">线粒体是细胞中负责哪项生命活动的细胞器？</textarea>
    <div class="cnt">0 / 200</div>
  </div>
  <div class="field-t mt16">背面</div>
  <div class="field">
    <textarea rows="3">有氧呼吸。线粒体被称为细胞的「动力工厂」</textarea>
    <div class="cnt">0 / 500</div>
  </div>

  <div class="tools">
    ${[['图片','image','var(--prim)','var(--prim-l)','permCamera'],
       ['录音','mic','var(--purple)','var(--purple-l)','permCamera'],
       ['拍照','camera','var(--orange)','var(--orange-l)','permCamera'],
       ['公式','star','var(--green)','var(--green-l)','']].map(([t,i,c,b,g])=>`
    <button class="tool-i" ${g?`data-go="${g}"`:'data-act="noop"'}>
      <div class="ti" style="background:${b}">${ic(i,17)}</div>
      <span style="color:${c}">${t}</span>
    </button>`).join('')}
  </div>

  <div class="ai-chip" style="background:var(--prim-l)" data-go="aipreview">
    <div style="color:var(--prim);flex:0 0 auto">${ic('sparkle',22)}</div>
    <div><div class="n" style="color:var(--prim-d)">粘贴多行文本，可自动拆成多张</div>
    <div class="d">试试：一行一张，用空格或逗号分隔</div></div>
  </div>

  <button class="btn ghost sm mt16" data-go="offline">（演示）无网络时</button>

  <div class="card mt16">
    <div class="between">
      <b style="font-size:14px">更多选项</b>
      <span style="color:var(--txt3)">${ic('arrowR',18)}</span>
    </div>
    <div class="chips">
      ${['基础卡','填空卡','双向卡'].map((t,i)=>
        `<button class="chip ${S.cardType===i?'on':''}" data-act="ctype" data-v="${i}">${t}</button>`).join('')}
    </div>
  </div>
  <div class="tiny" style="margin-top:14px;text-align:center">保存后可以直接开刷，不用先建牌组</div>
</div>`;

/* ===== AI 预览 ===== */
PAGES.aipreview = () => {
  const cards = [
    ['线粒体是有氧呼吸的主要场所，被称为？','细胞的「动力工厂」'],
    ['叶绿体存在于哪类细胞中？','绿色植物细胞'],
    ['光合作用发生的场所是？','叶绿体'],
  ];
  const n = S.aiSel.filter(Boolean).length;
  return `
<div class="navbar">
  <button class="icon-btn" data-go="create" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">AI 生成了 6 张</h1>
  <div class="spacer"></div>
  <button class="action" data-act="selectall">全选</button>
</div>
<div class="body">
  <div class="warn">
    <span style="color:var(--orange);flex:0 0 auto;margin-top:1px">${ic('shield',20)}</span>
    <div><div class="wt">请逐张确认后再入库</div>
    <div class="wd">未确认的卡片不会进入复习队列</div></div>
  </div>

  ${cards.map(([q,a],i)=>`
  <div class="dcard ${S.aiSel[i]?'':'off'}">
    <button class="cbox ${S.aiSel[i]?'on':''}" data-act="toggle" data-v="${i}">
      ${S.aiSel[i]?ic('check',13):''}
    </button>
    <div style="min-width:0">
      <div class="q">${q}</div>
      <div class="a">→ ${a}</div>
    </div>
    <div class="acts">
      <button data-go="cardEdit" style="color:var(--txt2)">${ic('edit',18)}</button>
      <button data-act="del" data-v="${i}" style="color:var(--red)">${ic('close',18)}</button>
    </div>
  </div>`).join('')}

  <div class="tiny" style="margin:6px 2px 16px">已确认 ${n} / 6 张</div>
  <div class="row" style="gap:11px;padding-bottom:20px">
    <button class="btn ghost sm" data-go="errAi" style="flex:1">重新生成</button>
    <button class="btn sm" data-act="confirm" style="flex:1">确认（${n}）</button>
  </div>
</div>`;
};

/* ===== 卡片管理 ===== */
PAGES.cards = () => `
<div class="navbar"><h1>卡片</h1></div>
<div class="body haspad">
  <div class="searchbar">${ic('search',18)} 搜索卡片或牌组</div>
  <div class="between mt20" style="margin-bottom:12px">
    <b style="font-size:15px">我的牌组</b><span class="tiny">3 个</span>
  </div>
  ${[['考研英语核心词','2400 张','今日 12',35,'var(--purple)','var(--purple-l)','star'],
     ['医学考点精选','860 张','今日 8',62,'var(--orange)','var(--orange-l)','shield'],
     ['我的随手记','42 张','今日 0',10,'var(--green)','var(--green-l)','edit']].map(([n,c,t,p,col,bg,i])=>`
  <div class="deck" data-go="deck">
    <div class="row" style="gap:14px">
      <div style="width:46px;height:46px;border-radius:14px;background:${bg};color:${col};display:grid;place-items:center;flex:0 0 auto">${ic(i,24)}</div>
      <div style="min-width:0">
        <div class="n">${n}</div>
        <div class="c">${c}</div>
      </div>
      <span class="today ${t==='今日 0'?'zero':''}" style="margin-left:auto">${t}</span>
    </div>
    <div class="dbar"><i style="width:${p}%;background:${col}"></i></div>
  </div>`).join('')}
  <div class="tiny" style="margin-top:10px;text-align:center">点任一牌组可查看详情</div>
</div>
<button class="fab" data-go="create">${ic('plus',26)}</button>
${tab('cards')}`;


/* ===== 回收站（P16 / P16b / P16c） =====
   存在意义：数据层的「30 天可恢复」已由 DeckLifecycleService 实现，
   但用户必须能找到恢复入口 —— 否则该承诺在产品层并不成立。
   设计原则：不制造焦虑。不写「已逾期」，写「还剩 N 天」；
             到期清理要说明「复习记录会保留」，避免用户担心白学了。
*/

/* 天数徽章：>7 天中性，<=7 天提醒色，但不用红色恐吓 */
function daysBadge(d){
  const warn = d <= 7;
  const bg = warn ? 'var(--orange-l)' : 'var(--div2)';
  const fg = warn ? 'var(--orange)' : 'var(--txt2)';
  return `<span style="margin-left:auto;flex:0 0 auto;font-size:12px;font-weight:700;
    padding:5px 11px;border-radius:20px;background:${bg};color:${fg}">还剩 ${d} 天</span>`;
}

PAGES.trash = () => `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">回收站</h1>
  <div class="spacer"></div>
</div>
<div class="body haspad">
  <div class="card" style="background:var(--prim-l);padding:14px 16px">
    <div class="row" style="gap:11px;color:var(--prim)">
      ${ic('info',19)}
      <span style="font-size:13.5px;font-weight:800;color:var(--prim)">30 天内可以完整恢复</span>
    </div>
    <div class="tiny" style="margin-top:8px;line-height:1.75;color:var(--txt2)">
      到期后会自动清理，但<b>已经积累的复习记录会保留</b>，
      不会让你白学，也不影响记忆安排。
    </div>
  </div>

  <div class="between mt20" style="margin-bottom:11px">
    <b style="font-size:15px">牌组</b><span class="tiny">1 个</span>
  </div>
  <div class="deck">
    <div class="row" style="gap:13px">
      <div style="width:44px;height:44px;border-radius:13px;background:var(--purple-l);color:var(--purple);display:grid;place-items:center;flex:0 0 auto">
        ${ic('layers',22)}
      </div>
      <div style="min-width:0">
        <div class="n">公考常识判断</div>
        <div class="c">320 张卡片 · 3 天前删除</div>
      </div>
      ${daysBadge(27)}
    </div>
    <div class="row" style="gap:8px;margin-top:13px">
      <button class="btn ghost sm" style="flex:1" data-act="restore" data-v="deck">恢复</button>
      <button class="btn gray sm" style="flex:0 0 96px" data-act="purge" data-v="deck">彻底删除</button>
    </div>
  </div>

  <div class="between mt20" style="margin:18px 0 11px">
    <b style="font-size:15px">卡片</b><span class="tiny">2 张</span>
  </div>
  ${[['线粒体是细胞中负责哪项……','有氧呼吸 · 医学考点精选',19,'edit'],
     ['《民法典》施行时间是？','2021 年 1 月 1 日 · 随手记',2,'doc']]
    .map(([t,s2,d,i])=>`
  <div class="deck">
    <div class="row" style="gap:13px">
      <div style="width:44px;height:44px;border-radius:13px;background:var(--div2);color:var(--txt2);display:grid;place-items:center;flex:0 0 auto">
        ${ic(i,21)}
      </div>
      <div style="min-width:0;flex:1">
        <div class="n" style="font-size:14.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${t}</div>
        <div class="c" style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${s2}</div>
      </div>
      ${daysBadge(d)}
    </div>
    <div class="row" style="gap:8px;margin-top:13px">
      <button class="btn ghost sm" style="flex:1" data-act="restore" data-v="card">恢复</button>
      <button class="btn gray sm" style="flex:0 0 96px" data-act="purge" data-v="card">彻底删除</button>
    </div>
  </div>`).join('')}

  <div class="tiny" style="margin-top:16px;text-align:center;line-height:1.7">
    恢复牌组时，只恢复随牌组一起删除的卡片；<br/>你单独删除的卡片不会被一并捞回。
  </div>
  <button class="btn ghost sm" style="margin-top:14px" data-go="trashEmpty">（演示）空态</button>
</div>`;

PAGES.trashEmpty = () => `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">回收站</h1>
  <div class="spacer"></div>
</div>
<div class="body haspad" style="display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding-top:60px">
  <div style="width:104px;height:104px;border-radius:50%;background:var(--div2);color:var(--txt3);display:grid;place-items:center">
    ${ic('trash',46)}
  </div>
  <div style="font-size:19px;font-weight:800;margin-top:22px">回收站是空的</div>
  <div class="tiny" style="margin-top:10px;line-height:1.85">
    删除的牌组和卡片会先放到这里，<br/>
    30 天内随时可以完整找回来。
  </div>
  <button class="btn ghost sm" style="margin-top:22px" data-go="cards">回到卡片</button>
</div>`;

/* 删除确认：叠加在来源页之上，明确告知「30 天内可恢复」 */
PAGES.deleteConfirm = () => {
  const isDeck = S.delKind !== 'card';
  const title = isDeck ? '删除「医学考点精选」？' : '删除这张卡片？';
  const body = isDeck
    ? '牌组内的 <b>860 张卡片</b>会一起移入回收站，<b>30 天内可以完整恢复</b>。'
    : '这张卡会移入回收站，<b>30 天内可以完整恢复</b>。';
  const btn = isDeck ? '移入回收站' : '移入回收站';
  return (isDeck ? PAGES.deck() : PAGES.cardEdit()) + `
<div style="position:absolute;inset:0;background:rgba(15,23,42,.5);display:flex;align-items:center;justify-content:center;padding:24px;z-index:60">
  <div style="background:var(--card);border-radius:24px;padding:22px;width:100%;max-width:330px;box-shadow:0 20px 50px rgba(0,0,0,.25)">
    <div style="width:52px;height:52px;border-radius:50%;background:var(--orange-l);color:var(--orange);display:grid;place-items:center;margin:0 auto 14px">
      ${ic('trash',26)}
    </div>
    <div style="font-size:17px;font-weight:800;text-align:center;line-height:1.45">${title}</div>
    <div style="font-size:13px;color:var(--txt2);text-align:center;line-height:1.8;margin-top:10px">${body}</div>
    <div style="margin-top:14px;padding:11px 13px;background:var(--green-l);border-radius:13px">
      <div class="row" style="gap:9px;color:var(--green)">
        ${ic('shield',17)}
        <span style="font-size:12px;font-weight:700;color:var(--green)">复习记录不会丢失</span>
      </div>
    </div>
    <div class="row" style="gap:9px;margin-top:16px">
      <button class="btn gray sm" style="flex:1" data-go="${isDeck?'deck':'cards'}">取消</button>
      <button class="btn sm" style="flex:1.15" data-act="doDelete">${btn}</button>
    </div>
  </div>
</div>`;
};


/* ===== 我的 ===== */
PAGES.my = () => {
  const rows = [
    ['chart','统计与进度','查看学习数据','stats'],
    ['bell','每日提醒','每天 20:00','reminder'],
    ['download','导入牌组','支持 .apkg / JSON','importPage'],
    ['download','导出与备份','永久免费 · 不设限','exportPage'],
    ['trash','回收站','2 项待恢复','trash'],
    ['cloud','云同步与备份','未登录',null],
    ['settings','偏好设置','卡片类型、手势、字号','settings'],
    ['shield','隐私与数据','本地优先，无需注册',null],
    ['info','关于与反馈','版本 1.0.0 · FSRS-6','about'],
  ];
  return `
<div class="navbar"><h1>我的</h1></div>
<div class="body haspad">
  <div class="card row" style="gap:14px">
    <div style="width:52px;height:52px;border-radius:50%;background:var(--prim-l);color:var(--prim);display:grid;place-items:center;flex:0 0 auto">
      ${ic('user',28)}
    </div>
    <div>
      <div style="font-size:17px;font-weight:700">未登录</div>
      <div class="tiny" style="margin-top:3px">不注册也能完整使用核心功能</div>
    </div>
  </div>

  <div class="card mt16" style="padding:6px 0">
    ${rows.map(([i,t,s,go2])=>`
    <button class="row" ${go2?`data-go="${go2}"`:'data-act="noop"'}
      style="width:100%;gap:14px;padding:14px 16px;border-bottom:1px solid var(--div2)">
      <span style="color:var(--txt2);flex:0 0 auto">${ic(i,21)}</span>
      <span style="min-width:0;text-align:left">
        <span style="display:block;font-size:15px;font-weight:600">${t}</span>
        <span class="tiny">${s}</span>
      </span>
      <span style="margin-left:auto;color:var(--txt3);flex:0 0 auto">${ic('arrowR',17)}</span>
    </button>`).join('')}
  </div>

  <div class="card mt16" style="background:var(--green-l)">
    <div class="row" style="gap:12px;color:var(--green)">
      ${ic('shield',22)}
      <div style="font-size:13.5px;font-weight:700;color:var(--green)">导出永久免费、永不设限</div>
    </div>
    <div class="tiny" style="margin-top:8px;line-height:1.7;color:var(--txt2)">
      你的卡片是你的资产。任何时候都可以完整导出为 .apkg 或 JSON。
    </div>
  </div>
</div>
${tab('my')}`;
};

/* ===== 统计 ===== */
PAGES.stats = () => {
  const heat=[3,1,0,2,4,3,0,1,4,2,3,3,1,0,2,4,4,1,3,2,0,4,3,1,2,4,0,3,4,2,1,3,0,4,2,3,1,0,4,3,2,1];
  const cols=['#EDF1F5','#C6E0FF','#7FB8FF','#3395FF','#0B5CD8'];
  const dcols=['#2A2E35','#16416F','#1D5FA8','#2E86E0','#5AA9F5'];
  const pal=S.dark?dcols:cols;
  const vals=[12,9,15,8,11,6,13], mx=Math.max(...vals);
  const R=42, C=2*Math.PI*R;
  return `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:22px">统计</h1>
</div>
<div class="body">
  <div class="streak">
    <span style="color:var(--orange);flex:0 0 auto">${ic('flame',34)}</span>
    <div>
      <div class="v">12<small>天</small></div>
      <div class="k">连续打卡</div>
      <div class="x">最长纪录 21 天</div>
    </div>
  </div>

  <div class="stat2">
    <div class="card" style="padding:14px">
      <div class="ring-wrap">
        <div class="ring">
          <svg width="96" height="96" viewBox="0 0 96 96">
            <circle cx="48" cy="48" r="${R}" fill="none" stroke="var(--div)" stroke-width="11"/>
            <circle cx="48" cy="48" r="${R}" fill="none" stroke="var(--green)" stroke-width="11"
              stroke-linecap="round" stroke-dasharray="${(C*0.86).toFixed(1)} ${C.toFixed(1)}"/>
          </svg>
          <div class="rv"><div style="text-align:center"><b style="font-size:24px">86%</b>
            <span style="display:block;font-size:11.5px;color:var(--txt2);margin-top:2px">今日完成</span></div></div>
        </div>
      </div>
    </div>
    <div class="card" style="padding:14px;display:grid;place-items:center;text-align:center">
      <div style="font-size:32px;font-weight:800">412</div>
      <div class="tiny" style="margin-top:5px">本月复习</div>
      <div style="font-size:11.5px;color:var(--green);font-weight:700;margin-top:6px">较上月 +38%</div>
    </div>
  </div>

  <div class="card">
    <div class="between"><b style="font-size:14px">未来 7 天复习量</b><span class="tiny">共约 74 张</span></div>
    <div class="forecast">
      ${vals.map((v,i)=>`
      <div class="fc ${i===2?'hi':''}">
        <span style="font-size:10.5px;color:${i===2?'var(--prim)':'var(--txt2)'};font-weight:700">${v}</span>
        <i style="height:${Math.max(6,52*v/mx)}px"></i>
        <span>${'一二三四五六日'[i]}</span>
      </div>`).join('')}
    </div>
  </div>

  <div class="card mt12">
    <div class="between"><b style="font-size:14px">学习热力图</b><span class="tiny">近 10 周</span></div>
    <div style="display:grid;grid-template-columns:repeat(14,1fr);gap:4px;margin-top:12px">
      ${heat.map(v=>`<i style="aspect-ratio:1;border-radius:4px;background:${pal[v]}"></i>`).join('')}
    </div>
    <div class="between tiny" style="margin-top:10px"><span>少</span><span>多</span></div>
  </div>
</div>`;
};

/* ===== 回归引导 ===== */
PAGES.back = () => `
<div class="welcome">
  <div class="ring2"><i style="color:#fff">${ic('home',38)}</i></div>
  <h2>欢迎回来！</h2>
  <p>有几天没见了，完全没关系</p>

  <div class="plan-card">
    <div style="font-size:17px;font-weight:700">先来 15 张热热身？</div>
    <div class="tiny" style="margin-top:6px;line-height:1.6">剩下的我们分 3 天慢慢补上<br>不催你，也不显示积压数字</div>
  </div>

  <div class="plan-card" style="margin-top:12px">
    <div class="plan-row"><span class="d">第 1 天</span><span class="v">15 张</span></div>
    <div class="progress"><i style="width:34%"></i></div>
    <div class="tiny" style="margin-top:10px">第 2 天约 20 张 · 第 3 天回到常规</div>
  </div>

  <div style="flex:1"></div>
  <button class="btn" data-go="review" style="width:100%">好的，开始</button>
  <button class="row" data-go="home" style="color:var(--txt2);font-size:13.5px;margin-top:16px;padding:6px">
    今天先看看，明天再开始
  </button>
</div>`;

/* ===== 桌面 widget ===== */
PAGES.widget = () => {
  const R=30, C=2*Math.PI*R;
  return `
<div class="wall">
  <div class="wall-time">
    <div class="t">9:41</div>
    <div class="d">9月15日 星期二</div>
  </div>

  <div class="appicons">
    ${['bell','doc','image','clock'].map(i=>`<div>${ic(i,22)}</div>`).join('')}
  </div>

  <div class="widget">
    <div class="wh">
      <span class="wn">瞄一眼</span>
      <span class="wb">${ic('cards',18)}</span>
    </div>
    <div class="wl">今天还剩</div>
    <div class="wv">${S.queue}<small>张</small></div>
    <div class="wd">约 ${Math.max(1,Math.round(S.queue*0.4))} 分钟</div>
    <button class="wbtn" data-go="review">继续复习</button>
    <div class="wring">
      <svg width="70" height="70" viewBox="0 0 70 70">
        <circle cx="35" cy="35" r="${R}" fill="none" stroke="#EDEFF2" stroke-width="8"/>
        <circle cx="35" cy="35" r="${R}" fill="none" stroke="var(--prim)" stroke-width="8"
          stroke-linecap="round" stroke-dasharray="${(C*0.4).toFixed(1)} ${C.toFixed(1)}"/>
      </svg>
      <b>40%</b>
    </div>
  </div>

  <div class="dock">
    ${['home','cards','chart','user'].map(i=>`<div>${ic(i,22)}</div>`).join('')}
  </div>

  <div style="position:absolute;left:20px;right:20px;bottom:118px;display:flex;gap:9px;z-index:2">
    <button data-go="liveWindow" style="flex:1;background:rgba(255,255,255,.9);color:var(--prim-d);font-size:12.5px;font-weight:700;padding:11px;border-radius:16px">
      锁屏实况窗
    </button>
    <button data-go="handoff" style="flex:1;background:rgba(255,255,255,.9);color:var(--prim-d);font-size:12.5px;font-weight:700;padding:11px;border-radius:16px">
      多端接续
    </button>
    <button data-go="tablet" style="flex:1;background:rgba(255,255,255,.9);color:var(--prim-d);font-size:12.5px;font-weight:700;padding:11px;border-radius:16px">
      平板布局
    </button>
  </div>
</div>`;
};

/* =========================================================
   补充页面：空状态 / 错误态 / 权限 / 数据流程
   ========================================================= */

/* ===== 首页 · 全新用户空态 ===== */
PAGES.emptyHome = () => `
<div class="navbar"><h1>今天</h1><div class="spacer"></div>
  <button class="icon-btn" data-act="noop" style="color:var(--txt2)">${ic('bell',22)}</button>
</div>
<div class="empty">
  <div class="empty-art">${ic('sparkle',60)}</div>
  <h3>还没有卡片</h3>
  <p>把想记住的东西丢进来，<br>剩下的交给我们安排。</p>
  <button class="btn" data-go="create">做第一张卡</button>
  <button class="btn ghost sm" data-go="onb1" style="margin-top:10px">看看精选牌组</button>
  <div class="empty-tips">
    <div class="et-t">三种开始方式</div>
    <div class="et-i"><b>①</b><span>手动写一张，正面问题、背面答案</span></div>
    <div class="et-i"><b>②</b><span>拍照或粘贴一段笔记，AI 帮你拆成多张</span></div>
    <div class="et-i"><b>③</b><span>导入现成的 .apkg 牌组</span></div>
  </div>
</div>
${tab('home')}`;

/* ===== 卡片页 · 空态 ===== */
PAGES.emptyCards = () => `
<div class="navbar"><h1>卡片</h1></div>
<div class="empty">
  <div class="empty-art" style="background:var(--purple-l);color:var(--purple)">${ic('cards',58)}</div>
  <h3>这里还空着</h3>
  <p>创建第一个牌组，<br>或者导入你已有的卡片。</p>
  <button class="btn" data-go="create">新建卡片</button>
  <button class="btn ghost sm" data-go="importPage" style="margin-top:10px">导入牌组</button>
</div>
<button class="fab" data-go="create">${ic('plus',26)}</button>
${tab('cards')}`;

/* ===== 搜索无结果 ===== */
PAGES.emptySearch = () => `
<div class="navbar"><h1>卡片</h1></div>
<div class="body haspad">
  <div class="searchbar">${ic('search',18)} 线粒体功能
    <button data-go="cards" style="margin-left:auto;color:var(--txt3)">${ic('close',17)}</button>
  </div>
  <div class="empty" style="padding-top:70px">
    <div class="empty-art" style="width:104px;height:104px;background:var(--div2);color:var(--txt3)">
      ${ic('search',46)}
    </div>
    <h3 style="font-size:18px">没找到「线粒体功能」</h3>
    <p style="font-size:13.5px">换个关键词试试，或者直接新建一张。</p>
    <div class="empty-tips" style="margin-top:20px">
      <div class="et-t">搜索建议</div>
      <div class="et-i"><b>·</b><span>检查是否有错别字</span></div>
      <div class="et-i"><b>·</b><span>试试更短的关键词</span></div>
      <div class="et-i"><b>·</b><span>搜索会同时匹配正面和背面</span></div>
    </div>
    <button class="btn sm" data-go="create" style="margin-top:20px">新建这张卡</button>
  </div>
</div>
${tab('cards')}`;

/* ===== AI 生成失败 ===== */
PAGES.errAi = () => `
<div class="navbar">
  <button class="icon-btn" data-go="create" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">AI 制卡</h1>
</div>
<div class="err-wrap">
  <div class="err-art warn">${ic('alert',46)}</div>
  <h3>这次没能生成卡片</h3>
  <p>内容可能太短，或者暂时处理不过来。<br>你写的内容都还在，可以直接手动制卡。</p>
  <div class="err-code">ERR_AI_TIMEOUT · 请求超时</div>

  <div class="err-detail">
    <div class="ed-r"><span>输入内容</span><span>2 段 · 86 字</span></div>
    <div class="ed-r"><span>处理方式</span><span>端侧模型</span></div>
    <div class="ed-r"><span>已消耗额度</span><span>0 张（失败不扣）</span></div>
  </div>

  <div class="err-acts">
    <button class="btn" data-act="noop">重试一次</button>
    <button class="btn ghost sm" data-go="create" style="margin-top:10px">改为手动制卡</button>
  </div>

  <div style="margin-top:20px;padding:13px 15px;background:var(--orange-l);border-radius:14px;text-align:left">
    <div style="font-size:12.5px;font-weight:700;color:var(--orange)">设计原则</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.65;margin-top:5px">
      失败不扣额度、不丢用户输入、必须给出「手动制卡」的退路。
      绝不让用户卡在死路上。
    </div>
  </div>
</div>`;

/* ===== 导入失败 ===== */
PAGES.errImport = () => `
<div class="navbar">
  <button class="icon-btn" data-go="importPage" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">导入牌组</h1>
</div>
<div class="err-wrap">
  <div class="err-art danger">${ic('xcircle',46)}</div>
  <h3>这个文件读不了</h3>
  <p>文件可能已损坏，或者不是支持的格式。<br>原始文件没有被修改。</p>
  <div class="err-code">ERR_UNSUPPORTED_FORMAT</div>

  <div class="err-detail">
    <div class="ed-r"><span>文件名</span><span>医学笔记.apkg</span></div>
    <div class="ed-r"><span>大小</span><span>12.4 MB</span></div>
    <div class="ed-r"><span>检测到的问题</span><span>缺少 collection 表</span></div>
  </div>

  <div class="err-acts">
    <button class="btn" data-go="importPage">换一个文件</button>
    <button class="btn ghost sm" data-act="noop" style="margin-top:10px">查看支持的格式</button>
  </div>

  <div style="margin-top:20px;padding:13px 15px;background:var(--card);border-radius:14px;text-align:left">
    <div style="font-size:12.5px;font-weight:700">支持导入</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.7;margin-top:5px">
      .apkg（Anki 牌组包）· .json（本应用导出）· .csv / .txt（纯文本，一行一张）
    </div>
  </div>
</div>`;

/* ===== 无网络 ===== */
PAGES.offline = () => `
<div class="navbar">
  <button class="icon-btn" data-go="create" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">AI 制卡</h1>
</div>
<div class="err-wrap">
  <div class="err-art info">${ic('wifioff',46)}</div>
  <h3>当前没有网络</h3>
  <p>AI 制卡这次需要联网。<br>不过手动制卡完全不受影响，<br>复习也照常可用。</p>

  <div class="err-detail">
    <div class="ed-r"><span>手动制卡</span><span style="color:var(--green);font-weight:700">可用</span></div>
    <div class="ed-r"><span>复习卡片</span><span style="color:var(--green);font-weight:700">可用</span></div>
    <div class="ed-r"><span>AI 制卡</span><span style="color:var(--orange);font-weight:700">需要网络</span></div>
    <div class="ed-r"><span>云同步</span><span style="color:var(--orange);font-weight:700">需要网络</span></div>
  </div>

  <div class="err-acts">
    <button class="btn" data-act="noop">重试</button>
    <button class="btn ghost sm" data-go="create" style="margin-top:10px">改用手动制卡</button>
  </div>

  <div style="margin-top:20px;padding:13px 15px;background:var(--green-l);border-radius:14px;text-align:left">
    <div style="font-size:12.5px;font-weight:700;color:var(--green)">离线优先</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.65;margin-top:5px">
      核心复习功能永远离线可用。断网时明确告知哪些能用、哪些不能，
      而不是让用户自己试出来。
    </div>
  </div>
</div>`;

/* ===== 通知权限（前置说明 + 系统弹窗） ===== */
PAGES.permNotify = () => `
<div class="pre-perm">
  <div class="pp-art">${ic('bell',66)}</div>
  <h3>要给你发个提醒吗？</h3>
  <p>每天固定时间提醒你今天的卡片。<br>一天只发一次，不会打扰你。</p>

  <div class="perm-list">
    <div class="perm-item">
      <span class="pi-ic">${ic('check',18)}</span>
      <div><div class="pi-t">一天只提醒一次</div>
      <div class="pi-d">在你设定的时间，比如每天 20:00</div></div>
    </div>
    <div class="perm-item">
      <span class="pi-ic">${ic('check',18)}</span>
      <div><div class="pi-t">文案温和，不制造焦虑</div>
      <div class="pi-d">「今天的 12 张已就绪」，不是「你有 800 张逾期」</div></div>
    </div>
    <div class="perm-item">
      <span class="pi-ic">${ic('check',18)}</span>
      <div><div class="pi-t">随时可以关掉</div>
      <div class="pi-d">关掉一次后我们不会再问第二次</div></div>
    </div>
  </div>

  <div style="flex:1"></div>
  <button class="btn" data-act="noop" style="margin-bottom:10px">开启提醒</button>
  <button class="row" data-go="my" style="color:var(--txt2);font-size:14px;justify-content:center;padding:8px">
    暂时不用
  </button>
</div>

<div class="scrim">
  <div class="sysdialog">
    <div class="sd-ic">${ic('shield',40)}</div>
    <div class="sd-t">由系统后台代理，不会弹授权框</div>
    <div class="sd-d">
      定时提醒用的是系统「后台代理提醒」，权限在安装时自动授予，<br>
      因此点「开启提醒」后<b>不会</b>再弹系统弹窗，直接生效。
    </div>
    <div style="background:var(--div2);border-radius:12px;padding:12px;margin-top:4px;text-align:left">
      <div style="font-size:11.5px;color:var(--txt2);line-height:1.7">
        唯一需要你手动处理的情况：在<b>系统设置</b>里关掉了本应用的通知。<br>
        那时请去「设置 › 通知 › 瞄一眼」重新打开。
      </div>
    </div>
    <div class="sd-btns">
      <button data-go="permDenied">（演示）已被关闭</button>
      <button data-act="noop">知道了</button>
    </div>
  </div>
</div>`;

/* ===== 相机权限 ===== */
PAGES.permCamera = () => `
<div class="pre-perm">
  <div class="pp-art" style="background:var(--purple-l);color:var(--purple)">${ic('camera',66)}</div>
  <h3>拍照制卡需要相机权限</h3>
  <p>拍下书上的一页、黑板上的笔记，<br>AI 会自动帮你拆成卡片。</p>

  <div class="perm-list">
    <div class="perm-item">
      <span class="pi-ic">${ic('check',18)}</span>
      <div><div class="pi-t">照片只在你的设备上处理</div>
      <div class="pi-d">优先使用端侧模型，不上传服务器</div></div>
    </div>
    <div class="perm-item">
      <span class="pi-ic">${ic('check',18)}</span>
      <div><div class="pi-t">只在你主动拍照时调用</div>
      <div class="pi-d">不会在后台访问相机或相册</div></div>
    </div>
    <div class="perm-item">
      <span class="pi-ic">${ic('check',18)}</span>
      <div><div class="pi-t">不授权也能用</div>
      <div class="pi-d">手动输入和粘贴文本不受影响</div></div>
    </div>
  </div>

  <div style="flex:1"></div>
  <button class="btn" data-act="noop" style="margin-bottom:10px">去授权</button>
  <button class="row" data-go="create" style="color:var(--txt2);font-size:14px;justify-content:center;padding:8px">
    改用手动输入
  </button>
</div>

<div class="scrim">
  <div class="sysdialog">
    <div class="sd-ic" style="color:var(--purple)">${ic('camera',40)}</div>
    <div class="sd-t">「瞄一眼」想访问你的相机</div>
    <div class="sd-d">用于拍摄照片并生成卡片。</div>
    <div class="sd-btns">
      <button data-go="permDenied">不允许</button>
      <button data-act="noop">仅使用时允许</button>
    </div>
  </div>
</div>`;

/* ===== 权限被拒后的引导 ===== */
PAGES.permDenied = () => `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">通知被关闭了</h1>
</div>
<div class="err-wrap">
  <div class="err-art info">${ic('lock',46)}</div>
  <h3>收不到每日提醒</h3>
  <p>你之前选择了不允许。<br>如果想重新开启，需要到系统设置里改。<br>
  <b style="color:var(--txt)">App 内不会再弹第二次。</b></p>

  <div class="err-detail">
    <div class="ed-r"><span>当前状态</span><span style="color:var(--orange);font-weight:700">通知已关闭</span></div>
    <div class="ed-r"><span>影响</span><span>收不到每日复习提醒</span></div>
    <div class="ed-r"><span>不影响</span><span>复习、制卡、统计数据</span></div>
  </div>

  <div class="err-acts">
    <button class="btn" data-act="noop">去系统设置开启</button>
    <button class="btn ghost sm" data-go="home" style="margin-top:10px">先不用，直接开始</button>
  </div>

  <div style="margin-top:20px;padding:13px 15px;background:var(--prim-l);border-radius:14px;text-align:left">
    <div style="font-size:12.5px;font-weight:700;color:var(--prim-d)">设计原则</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.65;margin-top:5px">
      权限被拒后不反复弹窗骚扰，只给一次明确引导 + 一条无负担的退路。
      关掉一次就是关掉了，这是尊重用户的选择。
    </div>
  </div>
</div>`;

/* ===== 导入页 ===== */
PAGES.importPage = () => `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">导入牌组</h1>
</div>
<div class="body">
  <div class="dropzone" data-go="importing">
    <div style="color:var(--prim)">${ic('upload',40)}</div>
    <div class="dz-t">点击选择文件</div>
    <div class="dz-s">也可以把文件拖到这里</div>
  </div>

  <div class="between mt20" style="margin-bottom:6px">
    <b style="font-size:14px">最近的文件</b><span class="tiny">3 个</span>
  </div>
  <div class="card" style="padding:4px 16px">
    ${[['医学笔记.apkg','12.4 MB · 昨天','orange','file'],
       ['考研核心词.apkg','8.1 MB · 3 天前','orange','file'],
       ['我的卡片备份.json','1.2 MB · 上周','blue','layers']].map(([n,s,c,i])=>`
    <button class="file-row" style="width:100%" data-go="importing">
      <div class="file-ic ${c==='blue'?'blue':''}" style="color:var(--${c})">${ic(i,22)}</div>
      <div style="min-width:0;text-align:left">
        <div class="file-n">${n}</div>
        <div class="file-s">${s}</div>
      </div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>`).join('')}
  </div>

  <div class="card mt16" style="background:var(--orange-l)">
    <div class="row" style="gap:12px;color:var(--orange)">
      ${ic('info',21)}
      <div style="font-size:13.5px;font-weight:700;color:var(--orange)">导入后不会立刻全部开刷</div>
    </div>
    <div class="tiny" style="margin-top:8px;line-height:1.7;color:var(--txt2)">
      为避免第一天被几千张卡淹没，导入的卡片会按每天 20 张的节奏分批安排。
      这是可预见的弃坑原因，必须在产品层拦住。
    </div>
  </div>

  <div class="card mt12">
    <div style="font-size:13px;font-weight:700;margin-bottom:10px">支持格式</div>
    <div class="tiny" style="line-height:1.9">
      · .apkg —— Anki 牌组包<br>
      · .json —— 本应用导出的备份<br>
      · .csv / .txt —— 一行一张，用逗号或 Tab 分隔
    </div>
  </div>

  <button class="btn ghost sm mt16" data-go="errImport">（演示）导入失败</button>
  <div style="height:16px"></div>
</div>`;

/* ===== 导入进行中 ===== */
PAGES.importing = () => `
<div class="navbar">
  <h1 style="font-size:21px">正在导入</h1>
</div>
<div class="body">
  <div class="card">
    <div class="row" style="gap:13px">
      <div class="file-ic">${ic('file',22)}</div>
      <div style="min-width:0">
        <div class="file-n">医学笔记.apkg</div>
        <div class="file-s">12.4 MB</div>
      </div>
    </div>
    <div class="bigprog"><i style="width:68%"></i></div>
    <div class="between" style="margin-top:10px">
      <span class="tiny">正在解析卡片…</span>
      <span class="tiny" style="font-weight:700;color:var(--prim)">68%</span>
    </div>
  </div>

  <div class="card mt12" style="padding:6px 16px">
    ${[['读取文件','完成',true],
       ['解析卡片结构','完成',true],
       ['提取媒体资源','进行中',null],
       ['写入本地数据库','等待',false]].map(([t,s,done])=>`
    <div class="set-row">
      <span style="flex:0 0 auto;color:${done===true?'var(--green)':(done===null?'var(--prim)':'var(--txt3)')}">
        ${done===true?ic('checkcircle',19):(done===null?ic('refresh',19):ic('info',19))}
      </span>
      <div><div class="sr-t" style="font-size:14px">${t}</div></div>
      <span style="margin-left:auto;font-size:12px;color:${done===true?'var(--green)':(done===null?'var(--prim)':'var(--txt3)')};font-weight:700">
        ${s}
      </span>
    </div>`).join('')}
  </div>

  <div class="tiny" style="margin-top:16px;text-align:center;line-height:1.7">
    导入过程中请不要关闭应用<br>大文件可能需要几分钟
  </div>

  <button class="btn ghost sm mt20" data-go="importOk">（演示）跳到完成</button>
</div>`;

/* ===== 导入完成 ===== */
PAGES.importOk = () => `
<div class="body" style="display:flex;flex-direction:column;justify-content:center;padding-top:0">
  <div class="result-ring" style="background:var(--green-l);color:var(--green)">
    ${ic('checkcircle',52)}
  </div>
  <div style="text-align:center">
    <div style="font-size:22px;font-weight:800">导入成功</div>
    <div class="tiny" style="margin-top:8px">医学笔记.apkg · 用时 18 秒</div>
  </div>

  <div class="card mt20" style="padding:6px 16px">
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid var(--div2)">
      <span style="font-size:14px">导入卡片</span><span style="font-weight:800">1,860 张</span>
    </div>
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid var(--div2)">
      <span style="font-size:14px">媒体资源</span><span style="font-weight:800">42 张图</span>
    </div>
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0">
      <span style="font-size:14px">跳过（重复/损坏）</span><span style="font-weight:800;color:var(--txt2)">7 张</span>
    </div>
  </div>

  <div class="card mt12" style="background:var(--prim-l)">
    <div class="row" style="gap:11px;color:var(--prim)">
      ${ic('info',20)}
      <div style="font-size:13.5px;font-weight:700;color:var(--prim-d)">已按每天 20 张分批安排</div>
    </div>
    <div class="tiny" style="margin-top:8px;line-height:1.7;color:var(--txt2)">
      1,860 张不会一次砸给你。今天先来 20 张，剩下的自动排进之后的日程。
    </div>
  </div>

  <div style="flex:1"></div>
  <div style="padding:16px 0 22px">
    <button class="btn" data-go="home">开始复习</button>
    <button class="row" data-go="cards" style="color:var(--txt2);font-size:14px;justify-content:center;padding:12px">
      先看看牌组
    </button>
  </div>
</div>`;

/* ===== 牌组详情 ===== */
PAGES.deck = () => `
<div class="navbar">
  <button class="icon-btn" data-go="cards" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:20px">医学考点精选</h1>
  <div class="spacer"></div>
  <button class="icon-btn" data-act="noop" style="color:var(--txt2)">${ic('more',21)}</button>
</div>
<div class="body">
  <div class="card" style="background:var(--orange-l)">
    <div class="row" style="gap:14px">
      <div style="width:50px;height:50px;border-radius:15px;background:var(--orange);color:#fff;display:grid;place-items:center;flex:0 0 auto">
        ${ic('shield',26)}
      </div>
      <div>
        <div style="font-size:18px;font-weight:800">医学考点精选</div>
        <div class="tiny" style="margin-top:3px">860 张 · 今日 8 张待复习</div>
      </div>
    </div>
  </div>

  <div class="stat2 mt12">
    <div class="stat">
      <div class="v" style="color:var(--prim)">8</div>
      <div class="k">今日待复习</div>
    </div>
    <div class="stat">
      <div class="v" style="color:var(--green)">412</div>
      <div class="k">已掌握</div>
      <div class="x">占比 48%</div>
    </div>
  </div>

  <div class="card">
    <div style="font-size:13.5px;font-weight:700;margin-bottom:12px">卡片状态分布</div>
    ${[['未学习',340,'var(--txt3)'],
       ['学习中',108,'var(--orange)'],
       ['复习中',412,'var(--green)']].map(([t,n,c])=>`
    <div style="margin-bottom:12px">
      <div class="between" style="font-size:12.5px;margin-bottom:6px">
        <span>${t}</span><span style="font-weight:700;color:${c}">${n}</span>
      </div>
      <div class="dbar"><i style="width:${n/860*100}%;background:${c}"></i></div>
    </div>`).join('')}
  </div>

  <div class="card mt12" style="padding:6px 16px">
    <button class="set-row" data-go="review">
      <span style="color:var(--prim)">${ic('cards',20)}</span>
      <div><div class="sr-t">开始复习这个牌组</div>
      <div class="sr-d">今日 8 张</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>
    <button class="set-row" data-act="noop">
      <span style="color:var(--txt2)">${ic('pause',20)}</span>
      <div><div class="sr-t">暂停这个牌组</div>
      <div class="sr-d">暂停后不再安排复习</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>
    <button class="set-row" data-act="noop">
      <span style="color:var(--red)">${ic('trash',20)}</span>
      <div><div class="sr-t" style="color:var(--red)">删除牌组</div>
      <div class="sr-d">会同时删除 860 张卡片</div></div>
    </button>
  </div>
  <div style="height:16px"></div>

  <button class="btn gray sm" style="margin-top:16px;color:var(--red)" data-act="askDelete" data-v="deck">
    ${ic('trash',18)} 删除这个牌组
  </button>
  <div style="height:10px"></div>
</div>`;

/* ===== 提醒设置 ===== */
PAGES.reminder = () => `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">每日提醒</h1>
</div>
<div class="body">
  <div class="card" style="padding:6px 16px">
    <div class="set-row">
      <span style="color:var(--prim)">${ic('bell',21)}</span>
      <div><div class="sr-t">开启每日提醒</div>
      <div class="sr-d">每天一次，不会重复打扰</div></div>
      <button class="switch on" data-act="noop" style="margin-left:auto"><i></i></button>
    </div>
  </div>

  <div class="card mt12">
    <div style="font-size:13.5px;font-weight:700">提醒时间</div>
    <div class="time-pick">
      ${['07:30','12:00','18:00','20:00','21:30','自定义'].map((t,i)=>
        `<button class="${i===3?'on':''}" data-act="noop">${t}</button>`).join('')}
    </div>
    <div class="tiny" style="margin-top:12px;line-height:1.7">
      建议选一个你通常有空的固定时间。<br>改了以后第二天生效。
    </div>
  </div>

  <div class="card mt12">
    <div style="font-size:13.5px;font-weight:700;margin-bottom:10px">提醒文案预览</div>
    <div style="background:var(--div2);border-radius:14px;padding:14px">
      <div class="row" style="gap:10px">
        <div style="width:34px;height:34px;border-radius:9px;background:var(--prim);color:#fff;display:grid;place-items:center;flex:0 0 auto">
          ${ic('cards',18)}
        </div>
        <div style="min-width:0">
          <div style="font-size:13px;font-weight:700">瞄一眼 · 现在</div>
          <div style="font-size:12.5px;color:var(--txt2);margin-top:3px">
            今天的 12 张已就绪，大约 5 分钟
          </div>
        </div>
      </div>
    </div>
    <div style="margin-top:12px;padding:11px 13px;background:var(--red-l);border-radius:12px">
      <div style="font-size:11.5px;color:var(--red);font-weight:700;line-height:1.6">
        ✕ 反例：「你有 800 张卡片逾期未复习！」<br>
        这种文案会制造负罪感，是新手弃坑的主要原因之一。
      </div>
    </div>
  </div>

  <div class="card mt12" style="padding:6px 16px">
    <button class="set-row" data-go="permNotify">
      <span style="color:var(--txt2)">${ic('lock',20)}</span>
      <div><div class="sr-t">通知权限</div>
      <div class="sr-d">已开启</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>
    <button class="set-row" data-go="permDenied">
      <span style="color:var(--txt2)">${ic('alert',20)}</span>
      <div><div class="sr-t">收不到提醒？</div>
      <div class="sr-d">检查系统通知设置</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>
  </div>
  <div style="height:16px"></div>
</div>`;

/* =========================================================
   补充页面：中断恢复 / 编辑 / 多端接续 / 实况窗
   ========================================================= */

/* ===== 复习中断恢复 ===== */
PAGES.resume = () => {
  const kept = 4;               // 已完成的张数
  const pct = Math.round(kept / S.total * 100);
  return `
<div class="body" style="display:flex;flex-direction:column;justify-content:center;padding:0 24px 40px">
  <div class="result-ring" style="background:var(--prim-l);color:var(--prim)">
    ${ic('pause',46)}
  </div>
  <div style="text-align:center">
    <div style="font-size:22px;font-weight:800">上次没复习完</div>
    <div class="tiny" style="margin-top:8px;line-height:1.7">
      已完成的 ${kept} 张都保存好了<br>中断在「${'生物学'}」第 ${kept+1} 张
    </div>
  </div>

  <div class="card mt20">
    <div class="between" style="margin-bottom:10px">
      <span style="font-size:13.5px;font-weight:700">本次进度</span>
      <span style="font-size:13px;font-weight:700;color:var(--prim)">${kept} / ${S.total}</span>
    </div>
    <div class="bigprog"><i style="width:${pct}%"></i></div>
    <div class="tiny" style="margin-top:10px">
      中断前的评分已全部写入日志，不会重复计数
    </div>
  </div>

  <div class="card mt12" style="padding:6px 16px">
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:12px 0;border-bottom:1px solid var(--div2)">
      <span style="font-size:13.5px">已完成</span><span style="font-weight:700;color:var(--green)">${kept} 张</span>
    </div>
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:12px 0">
      <span style="font-size:13.5px">剩余</span><span style="font-weight:700">${S.total-kept} 张 · 约 3 分钟</span>
    </div>
  </div>

  <div style="flex:1"></div>
  <div style="padding:16px 0 0">
    <button class="btn" data-go="review">从第 ${kept+1} 张继续</button>
    <button class="row" data-go="home" style="color:var(--txt2);font-size:14px;justify-content:center;padding:13px">
      今天先到这里
    </button>
  </div>
</div>`;
};

/* ===== 撤销评分反馈 ===== */
PAGES.undo = () => `
<div class="review-pad">
  <div class="rv-top">
    <div class="rv-bar"><i style="width:33%"></i></div>
    <span class="rv-count">还剩 8 张</span>
    <button class="icon-btn" data-act="noop" style="color:var(--txt2);width:28px">${ic('more',20)}</button>
  </div>

  <div class="qcard" data-act="flip">
    <div class="qcat">生物学</div>
    <div class="qtext">细胞中被称为「动力工厂」、是有氧呼吸主要场所的细胞器是什么？</div>
    <div class="qhint">提示：它的名字里有「体」字</div>
    <div class="swipe-hint">
      上滑查看答案
      <svg class="chev" viewBox="0 0 24 24"><path d="M5 15l7-7 7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>
    </div>
  </div>

  <button class="btn gray sm mt12" data-act="noop">${ic('undo',17)} 撤销上一次评分</button>
</div>

<!-- Snackbar：撤销后的即时反馈 -->
<div class="snackbar show">
  <span style="color:#fff;flex:0 0 auto">${ic('undo',18)}</span>
  <div style="min-width:0">
    <div style="font-size:13.5px;font-weight:700">已撤销上一次评分</div>
    <div style="font-size:11.5px;opacity:.8;margin-top:2px">
      恢复到「记得」之前 · 这张卡回到队列中
    </div>
  </div>
  <button style="color:#7FB8FF;font-size:13.5px;font-weight:700;flex:0 0 auto;margin-left:6px" data-act="noop">
    重做
  </button>
</div>`;

/* ===== 卡片编辑页 ===== */
PAGES.cardEdit = () => `
<div class="navbar">
  <button class="icon-btn" data-go="cards" style="color:var(--txt)">${ic('close',21)}</button>
  <h1 style="font-size:21px">编辑卡片</h1>
  <div class="spacer"></div>
  <button class="action" data-go="cards">完成</button>
</div>
<div class="body">
  <div class="field-t">正面</div>
  <div class="field">
    <textarea rows="3">线粒体是细胞中负责哪项生命活动的细胞器？</textarea>
    <div class="cnt">28 / 200</div>
  </div>
  <div class="field-t mt16">背面</div>
  <div class="field">
    <textarea rows="3">有氧呼吸。线粒体被称为细胞的「动力工厂」</textarea>
    <div class="cnt">21 / 500</div>
  </div>

  <div class="tools">
    ${[['图片','image','var(--prim)','var(--prim-l)'],
       ['录音','mic','var(--purple)','var(--purple-l)'],
       ['拍照','camera','var(--orange)','var(--orange-l)'],
       ['公式','star','var(--green)','var(--green-l)']].map(([t,i,c,b])=>`
    <button class="tool-i" data-act="noop">
      <div class="ti" style="background:${b}">${ic(i,17)}</div>
      <span style="color:${c}">${t}</span>
    </button>`).join('')}
  </div>

  <div class="card mt16" style="padding:6px 16px">
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid var(--div2)">
      <span style="font-size:13.5px">所属牌组</span>
      <span style="font-size:13.5px;font-weight:700;color:var(--prim)">医学考点精选 ›</span>
    </div>
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid var(--div2)">
      <span style="font-size:13.5px">已复习</span><span style="font-size:13.5px;font-weight:700">6 次</span>
    </div>
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0">
      <span style="font-size:13.5px">下次复习</span><span style="font-size:13.5px;font-weight:700">3 天后</span>
    </div>
  </div>

  <div class="card mt12" style="padding:6px 16px">
    <button class="set-row" data-act="noop">
      <span style="color:var(--txt2)">${ic('pause',20)}</span>
      <div><div class="sr-t">暂停这张卡</div>
      <div class="sr-d">暂时不再安排复习</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>
    <button class="set-row" data-act="noop">
      <span style="color:var(--orange)">${ic('refresh',20)}</span>
      <div><div class="sr-t">重置学习进度</div>
      <div class="sr-d">当作新卡重新开始</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>
    <button class="set-row" data-act="askDelete" data-v="card">
      <span style="color:var(--red)">${ic('trash',20)}</span>
      <div><div class="sr-t" style="color:var(--red)">删除这张卡</div>
      <div class="sr-d">移入回收站，30 天内可在回收站找回</div></div>
    </button>
  </div>

  <div style="margin-top:16px;padding:13px 15px;background:var(--prim-l);border-radius:14px">
    <div style="font-size:12.5px;font-weight:700;color:var(--prim-d)">与制卡页的区别</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.65;margin-top:5px">
      编辑页会展示复习历史，并允许删除 / 重置 / 暂停。
      这些操作都有二次确认，避免误触。
    </div>
  </div>
  <div style="height:16px"></div>
</div>`;

/* ===== 关于与反馈 ===== */
PAGES.about = () => `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">关于</h1>
</div>
<div class="body">
  <div style="text-align:center;padding:14px 0 22px">
    <img src="data:image/png;base64,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" style="width:76px;height:76px;border-radius:20px;display:block;margin:0 auto 14px">
    <div style="font-size:19px;font-weight:800">瞄一眼</div>
    <div style="font-size:12.5px;color:var(--prim);font-weight:700;margin-top:5px">五分钟，把该记的记了</div>
    <div class="tiny" style="margin-top:6px">版本 1.0.0 · HarmonyOS</div>
  </div>

  <div class="card" style="padding:6px 16px">
    ${[['memory','调度算法','FSRS-6',null],
       ['chart','目标留存率','90%',null],
       ['folder','本地卡片','860 张',null],
       ['clock','累计学习','32 小时',null]].map(([i,t,v])=>`
    <div class="set-row">
      <span style="color:var(--txt2)">${ic(i,20)}</span>
      <div><div class="sr-t">${t}</div></div>
      <span style="margin-left:auto;font-size:13.5px;font-weight:700">${v}</span>
    </div>`).join('')}
  </div>

  <div class="card mt12">
    <div style="font-size:13.5px;font-weight:700;margin-bottom:10px">关于算法</div>
    <div class="tiny" style="line-height:1.85">
      本应用采用 <b style="color:var(--txt)">FSRS-6</b>（Free Spaced Repetition Scheduler）
      调度算法，通过分析你的复习历史，在遗忘临界点安排复习，
      用更少的次数换取更久的记忆留存。<br><br>
      调度器为自研实现，默认参数取自 FSRS 官方
      （BSD-3-Clause 协议），未使用 Anki 的 rslib（AGPL-3.0）。
    </div>
  </div>

  <div class="card mt12" style="padding:6px 16px">
    <button class="set-row" data-act="noop">
      <span style="color:var(--prim)">${ic('message',20)}</span>
      <div><div class="sr-t">意见反馈</div>
      <div class="sr-d">我们会认真看每一条</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>
    <button class="set-row" data-act="noop">
      <span style="color:var(--orange)">${ic('star',20)}</span>
      <div><div class="sr-t">去应用市场评分</div>
      <div class="sr-d">你的评价对我们很重要</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('external',17)}</span>
    </button>
    <button class="set-row" data-act="noop">
      <span style="color:var(--green)">${ic('heart',20)}</span>
      <div><div class="sr-t">推荐给朋友</div>
      <div class="sr-d">好东西值得分享</div></div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('share',17)}</span>
    </button>
  </div>

  <div class="card mt12">
    <div style="font-size:13.5px;font-weight:700;margin-bottom:10px">开源协议</div>
    <div class="tiny" style="line-height:1.85">
      · fsrs（调度参数） —— BSD-3-Clause<br>
      · 图标与字体 —— 自行设计 / 开源字体<br>
      · 本应用完整源码协议见设置底部
    </div>
  </div>

  <div style="text-align:center;padding:22px 0 8px">
    <div class="tiny" style="line-height:1.8">
      记住一件事，不用花一整天<br>
      每天瞄一眼就够了<br>
      © 2026 瞄一眼
    </div>
  </div>
</div>`;

/* ===== 多端接续（平板上弹出） ===== */
PAGES.handoff = () => `
<div class="navbar"><h1>今天</h1><div class="spacer"></div>
  <button class="icon-btn" data-act="noop" style="color:var(--txt2)">${ic('bell',22)}</button>
</div>
<div class="body haspad">
  <div class="tiny" style="margin-bottom:12px">9 月 15 日 星期二</div>
  <div class="hero">
    <div class="lbl">还有</div>
    <div class="num">8<small>张</small></div>
    <div class="dur">约 3 分钟</div>
    <button class="btn-white" data-act="noop">开始复习</button>
  </div>
  <div class="stat2">
    <div class="stat">
      <div class="row" style="gap:5px;color:var(--orange)">${ic('flame',22)}</div>
      <div class="v">${S.streak}<small>天</small></div>
      <div class="k">连续打卡</div>
    </div>
    <div class="stat">
      <div class="v" style="color:var(--green)">86<small>%</small></div>
      <div class="k">本月完成率</div>
    </div>
  </div>
</div>
${tab('home')}

<!-- 接续弹窗 -->
<div class="scrim">
  <div class="sysdialog" style="text-align:left">
    <div style="padding:26px 22px 8px;display:flex;gap:14px;align-items:flex-start">
      <div style="width:48px;height:48px;border-radius:14px;background:var(--prim-l);color:var(--prim);display:grid;place-items:center;flex:0 0 auto">
        ${ic('tablet',26)}
      </div>
      <div style="min-width:0">
        <div style="font-size:17px;font-weight:800">在平板上继续？</div>
        <div style="font-size:13px;color:var(--txt2);line-height:1.65;margin-top:6px">
          手机上复习到一半 —— 生物学 · 还剩 8 张，
          可以直接接着背。
        </div>
      </div>
    </div>

    <div style="padding:12px 22px 20px">
      <div style="background:var(--div2);border-radius:14px;padding:13px 15px">
        <div class="between" style="margin-bottom:8px">
          <span style="font-size:12.5px;color:var(--txt2)">手机端进度</span>
          <span style="font-size:12.5px;font-weight:700;color:var(--prim)">4 / 12</span>
        </div>
        <div class="bigprog" style="margin-top:0"><i style="width:33%"></i></div>
        <div class="tiny" style="margin-top:9px">已完成的 4 张已同步</div>
      </div>
    </div>

    <div class="sd-btns">
      <button data-go="home">不用了</button>
      <button data-go="review">继续复习</button>
    </div>
  </div>
</div>`;

/* ===== 实况窗 / 锁屏进度 ===== */
PAGES.liveWindow = () => {
  const R = 26, C = 2 * Math.PI * R;
  return `
<div class="lock">
  <div class="lock-time">
    <div class="lt">9:41</div>
    <div class="ld">9月15日 星期二</div>
  </div>

  <div class="lock-notices">
    <!-- 实况窗：胶囊形态（顶部） -->
    <div class="live-pill">
      <div class="lp-ic">${ic('cards',17)}</div>
      <div class="lp-txt">
        <span class="lp-t">还剩 8 张</span>
        <span class="lp-s">生物学 · 约 3 分钟</span>
      </div>
      <div class="lp-bar"><i style="width:33%"></i></div>
    </div>

    <!-- 实况窗：卡片形态 -->
    <div class="live-card">
      <div class="lc-head">
        <div class="lc-ic">${ic('cards',18)}</div>
        <div style="min-width:0">
          <div class="lc-n">瞄一眼</div>
          <div class="lc-s">复习中 · 生物学</div>
        </div>
        <div class="lc-ring">
          <svg width="62" height="62" viewBox="0 0 62 62">
            <circle cx="31" cy="31" r="${R}" fill="none" stroke="rgba(255,255,255,.22)" stroke-width="6"/>
            <circle cx="31" cy="31" r="${R}" fill="none" stroke="#fff" stroke-width="6"
              stroke-linecap="round" stroke-dasharray="${(C*0.33).toFixed(1)} ${C.toFixed(1)}"/>
          </svg>
          <b>4/12</b>
        </div>
      </div>
      <div class="lc-bar"><i style="width:33%"></i></div>
      <div class="lc-foot">
        <span>还剩 8 张 · 约 3 分钟</span>
        <button data-go="review" class="lc-btn">继续</button>
      </div>
    </div>

    <!-- 普通通知 -->
    <div class="lock-notice">
      <div class="ln-ic">${ic('bell',16)}</div>
      <div style="min-width:0">
        <div class="ln-n">瞄一眼 <span>现在</span></div>
        <div class="ln-s">今天的 12 张已就绪，大约 5 分钟</div>
      </div>
    </div>
  </div>

  <div class="lock-hint">
    上滑解锁 · 实况窗在锁屏与状态栏常驻显示进度
  </div>
</div>`;
};

/* ===== 偏好设置 ===== */
PAGES.settings = () => `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">偏好设置</h1>
</div>
<div class="body">
  <div class="card" style="padding:6px 16px">
    <div class="set-row">
      <span style="color:var(--prim)">${ic('handoff',20)}</span>
      <div><div class="sr-t">手势优先</div>
      <div class="sr-d">上滑翻卡、左右滑评分</div></div>
      <button class="switch on" data-act="noop" style="margin-left:auto"><i></i></button>
    </div>
    <div class="set-row">
      <span style="color:var(--prim)">${ic('smartphone',20)}</span>
      <div><div class="sr-t">左手模式</div>
      <div class="sr-d">评分按钮移到左侧</div></div>
      <button class="switch" data-act="noop" style="margin-left:auto"><i></i></button>
    </div>
    <div class="set-row">
      <span style="color:var(--prim)">${ic('clock',20)}</span>
      <div><div class="sr-t">自动朗读</div>
      <div class="sr-d">翻卡时读出卡片内容</div></div>
      <button class="switch" data-act="noop" style="margin-left:auto"><i></i></button>
    </div>
  </div>

  <div class="card mt12">
    <div style="font-size:13.5px;font-weight:700">卡片字号</div>
    <div class="time-pick">
      ${['小','标准','大','特大'].map((t,i)=>
        `<button class="${i===1?'on':''}" data-act="noop">${t}</button>`).join('')}
    </div>
    <div class="tiny" style="margin-top:12px;line-height:1.7">
      默认「标准」。字号会同时影响复习页与卡片浏览。
    </div>
  </div>

  <div class="card mt12" style="padding:6px 16px">
    <div class="set-row">
      <span style="color:var(--txt2)">${ic('chart',20)}</span>
      <div><div class="sr-t">每日新卡上限</div>
      <div class="sr-d">防止一次性学太多</div></div>
      <span style="margin-left:auto;font-size:13.5px;font-weight:700">20 张 ›</span>
    </div>
    <div class="set-row">
      <span style="color:var(--txt2)">${ic('shield',20)}</span>
      <div style="min-width:0">
        <div class="sr-t">目标留存率</div>
        <div class="sr-d" style="max-width:230px">FSRS 参数，不建议随意调整，默认 90% 已适合大多数人</div>
      </div>
      <span style="margin-left:auto;font-size:13.5px;font-weight:700">90% ›</span>
    </div>
  </div>

  <div style="margin-top:16px;padding:13px 15px;background:var(--orange-l);border-radius:14px">
    <div style="font-size:12.5px;font-weight:700;color:var(--orange)">设计取舍</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.65;margin-top:5px">
      这一页刻意只有 6 个开关。Anki 有上百个选项，
      但每多一个选项，新手就要多一次决策 —— 这是它被劝退的原因之一。
    </div>
  </div>
  <div style="height:16px"></div>
</div>`;

/* ===== 导出与备份 ===== */
PAGES.exportPage = () => `
<div class="navbar">
  <button class="icon-btn" data-go="my" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">导出与备份</h1>
</div>
<div class="body">
  <div class="card" style="background:var(--green-l)">
    <div class="row" style="gap:12px;color:var(--green)">
      ${ic('shield',22)}
      <div style="font-size:14px;font-weight:700;color:var(--green)">导出永久免费、永不设限</div>
    </div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.7;margin-top:8px">
      你的卡片是你的资产。任何时候都能完整导出，不需要订阅，也没有张数上限。
    </div>
  </div>

  <div class="between mt20" style="margin-bottom:8px">
    <b style="font-size:14px">导出格式</b>
  </div>
  <div class="card" style="padding:6px 16px">
    ${[['.apkg','Anki 牌组包 · 可导入 Anki','orange','file'],
       ['.json','完整备份 · 可再导入本应用','blue','layers'],
       ['.csv','纯文本 · 一行一张，Excel 可打开','green','doc']].map(([t,s,c,i])=>`
    <button class="file-row" style="width:100%" data-go="importOk">
      <div class="file-ic ${c==='blue'?'blue':(c==='green'?'green':'')}" style="color:var(--${c})">${ic(i,22)}</div>
      <div style="min-width:0;text-align:left">
        <div class="file-n">${t}</div>
        <div class="file-s">${s}</div>
      </div>
      <span style="margin-left:auto;color:var(--txt3)">${ic('arrowR',17)}</span>
    </button>`).join('')}
  </div>

  <div class="card mt12" style="padding:6px 16px">
    <div class="set-row">
      <span style="color:var(--prim)">${ic('refresh',20)}</span>
      <div><div class="sr-t">自动本地备份</div>
      <div class="sr-d">每日本地快照，保留最近 7 份</div></div>
      <button class="switch on" data-act="noop" style="margin-left:auto"><i></i></button>
    </div>
  </div>

  <div class="card mt12" style="padding:6px 16px">
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid var(--div2)">
      <span style="font-size:13.5px">上次备份</span><span style="font-size:13.5px;font-weight:700">今天 08:12</span>
    </div>
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid var(--div2)">
      <span style="font-size:13.5px">备份大小</span><span style="font-size:13.5px;font-weight:700">3.2 MB</span>
    </div>
    <div class="ed-r" style="display:flex;justify-content:space-between;padding:13px 0">
      <span style="font-size:13.5px">包含媒体</span><span style="font-size:13.5px;font-weight:700">42 张图</span>
    </div>
  </div>

  <div style="margin-top:16px;padding:13px 15px;background:var(--card);border-radius:14px">
    <div style="font-size:12.5px;font-weight:700">为什么不对导出收费</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.65;margin-top:5px">
      竞品曾在导出上做限制导致口碑翻车。数据可迁移恰恰是用户信任的来源，
      也是本产品「不绑架用户」定位的一部分。
    </div>
  </div>
  <div style="height:16px"></div>
</div>`;

/* ===== 平板 / 折叠屏大屏布局 ===== */
PAGES.tablet = () => `
<div class="wide-body">
  <!-- 左侧栏：牌组列表 -->
  <aside class="wb-side">
    <div class="wb-brand">
      <div class="wb-logo">${ic('cards',20)}</div>
      <span>瞄一眼</span>
    </div>
    <div class="wb-nav">
      ${[['home','今天',true],['cards','卡片',false],['chart','统计',false],['user','我的',false]].map(([i,t,on])=>`
      <button class="wb-nav-i ${on?'on':''}">${ic(i,20)}<span>${t}</span></button>`).join('')}
    </div>
    <div class="wb-sec">我的牌组</div>
    <div class="wb-decks">
      ${[['医学考点精选','今日 8','var(--orange)','var(--orange-l)',true],
         ['考研英语核心词','今日 12','var(--purple)','var(--purple-l)',false],
         ['我的随手记','今日 0','var(--green)','var(--green-l)',false]].map(([n,t,c,b,on])=>`
      <button class="wb-deck ${on?'on':''}">
        <i style="background:${b};color:${c}"></i>
        <span style="min-width:0;flex:1;text-align:left">${n}</span>
        <em style="color:${c}">${t}</em>
      </button>`).join('')}
    </div>
    <button class="wb-new">${ic('plus',18)} 新建牌组</button>
  </aside>

  <!-- 右侧：复习区 -->
  <main class="wb-main">
    <div class="wb-top">
      <div>
        <div style="font-size:22px;font-weight:800">医学考点精选</div>
        <div class="tiny" style="margin-top:3px">今日 8 张 · 约 3 分钟</div>
      </div>
      <div class="wb-prog">
        <div class="bigprog" style="width:150px;margin-top:0"><i style="width:33%"></i></div>
        <span class="tiny" style="margin-top:6px;display:block;text-align:right">还剩 8 张</span>
      </div>
    </div>

    <div class="wb-card">
      <div class="wb-cat">生物学</div>
      <div class="wb-q">细胞中被称为「动力工厂」、是有氧呼吸主要场所的细胞器是什么？</div>
      <div class="wb-hint">提示：它的名字里有「体」字</div>
      <div class="wb-swipe">${ic('chevU',20)} 上滑查看答案</div>
    </div>

    <div class="wb-rate">
      ${[['再来一次','rb1'],['有点难','rb2'],['记得','rb3'],['太简单','rb4']].map(([t,c])=>
        `<button class="${c}" data-go="review"><span>${t}</span></button>`).join('')}
    </div>

    <div class="wb-tip">
      ${ic('info',16)}
      <span>一次开发多端部署 —— 手机 / 折叠屏 / 平板同一套 ArkTS 代码，大屏下自动切换为双栏布局</span>
    </div>
  </main>
</div>`;

/* ===== AI 生成中（加载态） ===== */
PAGES.aiLoading = () => `
<div class="navbar">
  <button class="icon-btn" data-go="create" style="color:var(--txt)">${ic('back',22)}</button>
  <h1 style="font-size:21px">正在生成卡片</h1>
</div>
<div class="body">
  <div class="card" style="text-align:center;padding:34px 20px">
    <div class="spinner-wrap">
      <div class="spinner"></div>
      <div style="margin-top:0">${ic('sparkle',26)}</div>
    </div>
    <div style="font-size:16px;font-weight:700;margin-top:20px">正在从 2 段内容里拆出卡片</div>
    <div class="tiny" style="margin-top:8px;line-height:1.7">通常需要 3 - 8 秒<br>生成结果会先给你逐张确认</div>
    <div class="bigprog" style="margin-top:22px"><i class="indet"></i></div>
  </div>

  <div class="card mt12" style="padding:6px 16px">
    ${[['读取内容','完成',true],
       ['识别知识点','进行中',null],
       ['生成卡片草稿','等待',false]].map(([t,s,st])=>`
    <div class="set-row">
      <span style="flex:0 0 auto;color:${st===true?'var(--green)':(st===null?'var(--prim)':'var(--txt3)')}">
        ${st===true?ic('checkcircle',19):(st===null?ic('refresh',19):ic('info',19))}
      </span>
      <div><div class="sr-t" style="font-size:14px">${t}</div></div>
      <span style="margin-left:auto;font-size:12px;font-weight:700;color:${st===true?'var(--green)':(st===null?'var(--prim)':'var(--txt3)')}">${s}</span>
    </div>`).join('')}
  </div>

  <button class="btn ghost sm mt16" data-act="noop">取消生成</button>

  <div style="margin-top:20px;padding:13px 15px;background:var(--prim-l);border-radius:14px">
    <div style="font-size:12.5px;font-weight:700;color:var(--prim-d)">设计要点</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.65;margin-top:5px">
      加载态不能只有一个转圈。<b>分步骤进度 + 明确的时间预期</b>
      能把「不知道要等多久」的焦虑降下来，也让用户理解结果为何需要确认。
      「取消」必须常驻可点 —— 生成到一半想放弃是合理诉求。
    </div>
  </div>
  <div style="height:16px"></div>
</div>`;

/* ===== 首页骨架屏（加载态） ===== */
PAGES.skeleton = () => `
<div class="navbar"><h1>今天</h1><div class="spacer"></div>
  <button class="icon-btn" data-act="noop" style="color:var(--txt2)">${ic('bell',22)}</button>
</div>
<div class="body haspad">
  <div class="sk sk-line" style="width:120px;height:13px;margin-bottom:12px"></div>
  <div class="sk sk-card" style="height:210px;border-radius:24px;margin-bottom:12px"></div>
  <div class="stat2">
    <div class="sk sk-card" style="height:108px;border-radius:20px"></div>
    <div class="sk sk-card" style="height:108px;border-radius:20px"></div>
  </div>
  <div class="sk sk-card mt12" style="height:96px;border-radius:20px"></div>
  <div class="sk sk-card mt12" style="height:140px;border-radius:20px"></div>

  <div style="margin-top:24px;padding:13px 15px;background:var(--prim-l);border-radius:14px">
    <div style="font-size:12.5px;font-weight:700;color:var(--prim-d)">设计要点</div>
    <div style="font-size:11.5px;color:var(--txt2);line-height:1.65;margin-top:5px">
      骨架屏的形状必须与真实内容一一对应，不能是随机灰色块。
      目标低于 300ms 时其实可以不显示骨架屏（会闪一下反而更差）——
      本页仅在首次冷启动或数据库升级迁移后出现。
    </div>
  </div>
</div>
${tab('home')}`;

/* ---------------- 渲染 ---------------- */
function render(){
  const scr = document.getElementById('screen');
  const ph = document.getElementById('phone');
  // 平板 / 折叠屏页需要更宽的画框
  if (ph) ph.classList.toggle('wide', S.screen === 'tablet');
  scr.innerHTML = PAGES[S.screen] ? PAGES[S.screen]() : '';

  const m = META[S.screen];
  const $ = id => document.getElementById(id);
  if ($('screenName')) $('screenName').textContent = m.name;
  if ($('screenPid')) $('screenPid').textContent = m.pid;

  // 状态栏：桌面 widget 为深底
  const sb = $('statusbar');
  if (sb) sb.classList.toggle('light',
    S.screen==='widget' || S.screen==='liveWindow' || S.dark);

  // 说明
  if ($('notes')) $('notes').innerHTML =
    (NOTES[S.screen]||[]).map(n=>`<li>${n}</li>`).join('');

  // 流程导航
  if ($('flowlist')) $('flowlist').innerHTML = FLOW.map(id=>
    `<button class="${S.screen===id?'on':''}" data-go="${id}">${META[id].name}</button>`
  ).join('');

  // 缩略图（按分组）
  if ($('thumbs')) $('thumbs').innerHTML = GROUPS.map(g=>`
    <div class="tgroup">
      <div class="tg-title">${g.title} <span>${g.ids.length}</span></div>
      <div class="tg-grid">
        ${g.ids.map(id=>`
          <button class="thumb ${S.screen===id?'on':''}" data-go="${id}">
            <div class="tp">${META[id].pid}</div>
            <div class="tn">${META[id].name.replace(/（.*?）/g,'').replace(/^.*·\s*/,'')}</div>
          </button>`).join('')}
      </div>
    </div>`).join('');
}

/* ---------------- 事件 ---------------- */
document.addEventListener('click', e => {
  const goEl = e.target.closest('[data-go]');
  const actEl = e.target.closest('[data-act]');

  if (actEl){
    const a = actEl.dataset.act, v = actEl.dataset.v;
    if (a==='flip'){ S.flipped = !S.flipped; render(); return; }
    if (a==='rate'){
      S.queue = Math.max(0, S.queue-1);
      S.flipped = false;
      if (S.queue===0){
        S.streak += 1;
        toast('本张已记录 · 下次再见它：3 天后');
        setTimeout(()=>{ go('done'); }, 320);
      } else {
        toast(['再来一次 · 明天再见','有点难 · 2 天后','记得 · 3 天后','太简单 · 7 天后'][v-1]);
        render();
      }
      return;
    }
    if (a==='skip'){ toast('已放到最后'); S.flipped=false; render(); return; }
    if (a==='askDelete'){ S.delKind = v || 'deck'; go('deleteConfirm'); return; }
    if (a==='doDelete'){
      toast(S.delKind==='card' ? '已移入回收站 · 30 天内可恢复' : '牌组与 860 张卡片已移入回收站');
      setTimeout(()=>go('trash'), 620);
      return;
    }
    if (a==='restore'){
      toast(v==='deck' ? '牌组已恢复 · 320 张卡片回来了' : '卡片已恢复到原牌组');
      return;
    }
    if (a==='purge'){
      toast(v==='deck' ? '已彻底删除，无法恢复' : '已彻底删除，无法恢复');
      return;
    }
    if (a==='plan'){ S.plan = +v; render(); return; }
    if (a==='ctype'){ S.cardType = +v; render(); return; }
    if (a==='toggle'){ S.aiSel[v] = !S.aiSel[v]; render(); return; }
    if (a==='del'){ S.aiSel[v] = false; toast('已移除这张草稿'); render(); return; }
    if (a==='selectall'){ S.aiSel = S.aiSel.map(()=>true); render(); return; }
    if (a==='confirm'){
      const n = S.aiSel.filter(Boolean).length;
      toast(n ? `已入库 ${n} 张，可以开始复习了` : '请先至少确认一张');
      if (n) setTimeout(()=>go('cards'), 700);
      return;
    }
    if (a==='save'){ toast('已保存 · 可以直接开刷'); setTimeout(()=>go('cards'),700); return; }
    if (a==='input'){ toast('已读取内容，正在生成卡片草稿…'); setTimeout(()=>go('aipreview'),700); return; }
    if (a==='noop'){ toast('该功能的详细流程不在本原型范围内'); return; }
  }

  if (goEl){ go(goEl.dataset.go); return; }
});

/* 深色模式 */
document.getElementById('darkToggle').addEventListener('click', ()=>{
  S.dark = !S.dark;
  document.body.classList.toggle('dark', S.dark);
  document.getElementById('darkToggle').classList.toggle('on', S.dark);
  render();
});

/* 重置 */
document.getElementById('resetBtn').addEventListener('click', ()=>{
  Object.assign(S, {screen:'home', plan:null, queue:12, total:12, flipped:false,
                    aiSel:[true,true,false], cardType:0, streak:3});
  render();
  toast('已重置到初始状态');
});

/* 支持通过 URL hash 直达某一屏，如 index.html#review */
(function(){
  const h = (location.hash||'').replace('#','');
  if (h && META[h]) S.screen = h;
})();

render();
