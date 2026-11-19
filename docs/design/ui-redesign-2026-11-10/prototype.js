/* Design review only. No API, storage, account or production state is used. */
(() => {
  'use strict';
  const $ = (selector, root = document) => root.querySelector(selector);
  const esc = (value) => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const paths = {
    fridge:'<rect x="5" y="2.5" width="14" height="19" rx="2"/><path d="M5 12h14M12 3v9M9 7v2M15 7v2M8 17h8"/>',
    recipe:'<path d="M4 3v6a3 3 0 0 0 6 0V3M7 3v18M18 3c-3 3-4 7 0 9v9M18 3v9"/>',
    home:'<path d="m3 11 9-8 9 8M5 10v11h14V10M9 21v-7h6v7"/>',
    people:'<circle cx="9" cy="7" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3M16 4a3 3 0 0 1 0 6M21 21v-3a6 6 0 0 0-4-5"/>',
    plus:'<path d="M12 5v14M5 12h14"/>', list:'<path d="M9 5h12M9 12h12M9 19h12M3 5h1M3 12h1M3 19h1"/>',
    arrow:'<path d="M5 12h14m-6-6 6 6-6 6"/>',chevron:'<path d="m9 5 7 7-7 7"/>',down:'<path d="m6 9 6 6 6-6"/>',
    clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',check:'<path d="m5 12 4 4L19 6"/>',
    close:'<path d="m6 6 12 12M18 6 6 18"/>',search:'<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
    info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/>',lock:'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 15v2"/>',
    rotate:'<path d="M3 10a9 9 0 1 1 2 8M3 3v7h7"/>',door:'<path d="M5 21V3h14v18M9 21V5l7-2v18M12 12h.01"/>',
    drawer:'<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M9 14h6M6 19v2M18 19v2"/>',
    milk:'<path d="M8 3h8v4l3 4v10H5V11l3-4V3ZM8 7h8M5 11h14M9 15h6M9 18h4"/>',
    leaf:'<path d="M20 3C10 2 3 7 4 14s14 8 16-11Z M4 21 15 10M8 17l1-6M12 13l5 1"/>',
    egg:'<path d="M19 14c0 5-3 8-7 8s-7-3-7-8S9 2 12 2s7 7 7 12Z"/>',
    tomato:'<path d="M12 7C2 2-1 20 9 21h6C25 20 22 2 12 7ZM12 7V2M8 4l4 3 4-3"/>',
    fish:'<path d="M18 12c-6-11-15-2-15-2l-2 2 2 2s9 9 15-2Zm0 0 4-5v10l-4-5ZM7 11h.01"/>',
    meat:'<path d="M15 3c5-1 9 7 3 12l-6 5c-3 2-7 0-8-3s0-6 3-8l8-6Z"/><circle cx="15" cy="9" r="3"/>',
    butter:'<path d="M3 9h18v11H3V9Zm2 0 2-5h10l2 5M3 14h18M8 17h8"/>',
    pantry:'<path d="M6 3h12l-1 4 2 14H5L7 7 6 3ZM7 7h10M8 12h8M9 16h6"/>',
    trash:'<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M9 10v7M15 10v7"/>',
    eye:'<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
    copy:'<rect x="8" y="8" width="12" height="13" rx="2"/><path d="M16 8V3H3v13h5"/>',
    sliders:'<path d="M4 3v7M4 14v7M12 3v12M12 19v2M20 3v3M20 10v11M1 10h6M9 15h6M17 6h6"/>',
    bowl:'<path d="M3 11a9 9 0 0 0 18 0H3ZM8 20h8M7 7l1-3M12 7V2M17 7l-1-3"/>',
  };
  const icon = (name, extra = '') => `<svg class="icon ${extra}" viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.info}</svg>`;
  const schemes = {
    a:{name:'静白全景',title:'让新鲜，各就其位。',tag:'MY KITCHEN',description:'厨房里的一切，简单一点，刚刚好。'},
    b:{name:'冷雾工作台',title:'打开厨房，开始今天。',tag:'KITCHEN WORKSPACE',description:'从一份清单开始，把每一餐安排得更从容。'},
    c:{name:'墨线橱窗',title:'新鲜日常，有迹可循。',tag:'THE EVERYDAY KITCHEN',description:'收好每一份食材，也照顾好每一天。'},
  };
  const params = new URLSearchParams(location.search);
  const scheme = Object.hasOwn(schemes, params.get('scheme')) ? params.get('scheme') : 'a';
  const validPages = ['home','foods','recipes','family','records','login','components'];
  const state = {
    scheme,page:validPages.includes(params.get('page')) ? params.get('page') : 'home',role:'OWNER',
    query:'',zone:'all',expiry:'all',sort:'expiry',openParts:new Set(),pending:false,modalType:null,dirty:false,
    register:false,undone:false,familyName:'林间小家',nextId:9,
    foods:[
      {id:1,name:'鲜牛奶',category:'奶制品',zone:'冷藏',quantity:1,unit:'盒',days:2,symbol:'milk',date:'2026-11-12'},
      {id:2,name:'西兰花',category:'蔬菜',zone:'冷藏',quantity:1,unit:'棵',days:1,symbol:'leaf',date:'2026-11-11'},
      {id:3,name:'鸡蛋',category:'蛋类',zone:'冷藏',quantity:6,unit:'个',days:6,symbol:'egg',date:'2026-11-16'},
      {id:4,name:'番茄',category:'蔬菜',zone:'冷藏',quantity:3,unit:'个',days:2,symbol:'tomato',date:'2026-11-12'},
      {id:5,name:'三文鱼',category:'水产',zone:'变温',quantity:1,unit:'份',days:-1,symbol:'fish',date:'2026-11-09'},
      {id:6,name:'鸡胸肉',category:'肉类',zone:'冷冻',quantity:2,unit:'份',days:15,symbol:'meat',date:'2026-11-25'},
      {id:7,name:'黄油',category:'奶制品',zone:'冷藏',quantity:1,unit:'盒',days:30,symbol:'butter',date:'2026-12-10'},
      {id:8,name:'意大利面',category:'主食',zone:'常温',quantity:1,unit:'袋',days:90,symbol:'pantry',date:'2027-02-08'},
    ],
  };
  const app = $('#app'), modal = $('#modal'), confirmDialog = $('#confirm-dialog');
  document.body.classList.add(`scheme-${scheme}`);
  let opener = null, toastTimer = null;
  document.title = `小易冰箱 · ${scheme.toUpperCase()} ${schemes[scheme].name} · 设计审查`;
  $('#scheme-picker').value = scheme;
  $('.review-tools-panel a').href = `prototype.html?scheme=${scheme}&page=components`;
  const writable = () => state.role !== 'VIEWER';
  const disabledWrite = () => writable() ? '' : 'disabled';
  const button = (label, action, cls = '', attrs = '') => `<button type="button" class="btn ${cls}" data-action="${action}" ${attrs}>${label}</button>`;
  const readonly = () => writable() ? '' : `<div class="readonly-banner">${icon('lock')}<span>你是只读成员，可以查看食材和菜谱；编辑需要家庭主人调整权限。</span></div>`;
  const pageHead = (title, subtitle, actions = '', cls = '') => `<div class="page-head ${cls}"><div><div class="eyebrow">${schemes[scheme].tag}</div><h1>${title}</h1><p>${subtitle}</p></div><div class="page-actions">${actions}</div></div>`;
  function nav(locationName) {
    const selected = ['foods','records'].includes(state.page) ? 'home' : state.page;
    return [['home','fridge','冰箱'],['recipes','recipe','菜谱'],['family','people','家庭']].map(([page,symbol,label]) => `<button class="nav-link ${selected===page?'active':''}" type="button" data-page="${page}" ${selected===page?'aria-current="page"':''} aria-label="${label}${locationName}">${icon(symbol)}<span>${label}</span></button>`).join('');
  }
  function render() {
    const renderer = {home:homeView,foods:foodsView,recipes:recipesView,family:familyView,records:recordsView,login:loginView,components:componentsView}[state.page];
    app.className = `app-shell scheme-${scheme}`;
    app.innerHTML = `<aside class="sidebar"><div class="sidebar-brand"><div class="brand-icon">${icon('fridge','large')}</div><span class="brand-word">小易冰箱</span></div><nav class="nav-links" aria-label="主导航">${nav('')}</nav><div class="sidebar-foot"><span class="avatar">林</span><div><small>林间小家</small><small>演示家庭</small></div></div></aside>
      <header class="topbar"><div class="brand-text">小易冰箱<span class="brand-sub">查食材，看菜谱，都容易</span></div><nav class="top-nav" aria-label="顶部导航">${nav('')}</nav><div class="topbar-actions"><button class="family-switch" type="button" data-page="family">${icon('home')}<span>${esc(state.familyName)}</span>${icon('down')}</button><span class="avatar">林</span></div></header>
      <main class="main-content">${readonly()}${renderer()}</main><nav class="bottom-nav" aria-label="底部导航">${nav('')}${state.page==='home'||state.page==='foods'?button(`${icon('plus')}<span>新增</span>`,'add','primary bottom-add',disabledWrite()):''}</nav>`;
    if (state.page === 'foods') updateFoodResults();
  }
  function homeView() {
    const urgent = state.foods.filter(f => f.days >= 0 && f.days <= 3).sort((a,b) => a.days-b.days);
    const expired = state.foods.filter(f => f.days < 0);
    const preview = scheme==='b' ? [...urgent,...state.foods.filter(f=>f.days>3)].slice(0,4) : urgent.slice(0,3);
    return `${pageHead(schemes[scheme].title,schemes[scheme].description,button(`${icon('list')}食材清单`,'foods')+button(`${icon('plus')}新增食材`,'add','primary',disabledWrite()),'home-head')}
      <div class="home-metrics"><div class="metric"><strong>${state.foods.length.toString().padStart(2,'0')}</strong><span>份在库食材</span></div><div class="metric"><strong>${urgent.length.toString().padStart(2,'0')}</strong><span>份即将到期</span></div><div class="metric"><strong>${expired.length.toString().padStart(2,'0')}</strong><span>份已过期 · 待检查</span></div><div class="metrics-note">${icon('clock')}演示快照 · 2026.11.10</div></div>
      <div class="home-workspace"><section class="scene-panel" aria-label="厨房场景参考"><div class="scene-visual"><img class="scene-photo" src="assets/kitchen-reference.png" alt="冷白自然光下的白色双门双抽屉冰箱，浅冷灰柜体、雾蓝瓷砖和石材台面"><div class="scene-top"><span class="scene-label">${icon('fridge')}我的厨房 · 默认冰箱</span><button class="icon-btn" type="button" data-action="reset-scene" aria-label="复位视角（样稿示意）">${icon('rotate')}</button></div><button type="button" class="zone-hotspot" data-action="cold">冷藏 · ${state.foods.filter(f=>f.zone==='冷藏').length} 份</button><div class="scene-caption">厨房材质 / 构图参考 · 非实时三维<br>门控按钮仅演示状态，图片不会开门</div></div><div class="scene-controls"><div class="scene-controls-title"><div class="eyebrow">SCENE CONTROLS</div><h2>把厨房<br>握在手边。</h2></div><div class="door-controls">${[['left','door','左门'],['right','door','右门'],['variable','drawer','变温抽屉'],['freezer','drawer','冷冻抽屉']].map(([part,symbol,name])=>`<button type="button" class="door-button" data-part="${part}" aria-pressed="${state.openParts.has(part)}">${icon(symbol)}${name}</button>`).join('')}<button type="button" class="door-button" data-action="close-all">全部关闭</button></div><div class="scene-controls-note">${icon('info')}冷藏 4°C / 冷冻 −18°C · 仅储存参考</div></div></section>
      <section class="stock-panel"><div class="section-head"><h2>${scheme==='b'?'食材工作台':'今天先用这些'}</h2><span class="muted">${scheme==='b'?'到期优先':urgent.length+' 份临期'}</span></div><p>${scheme==='b'?'先照顾临期，再安排下一餐。':'新鲜不等待，下一餐刚刚好。'}</p><div class="preview-list">${preview.length?preview.map(previewFood).join(''):'<div class="empty-state">暂时没有临期食材</div>'}</div>${expired.length?`<div class="expired-hint">${icon('info')}另有 ${expired.length} 份已过期，请先检查</div>`:''}<div class="stock-footer">${button(`查看全部 ${state.foods.length} 份 ${icon('arrow')}`,'foods','full')}${button(`${icon('clock')}操作记录`,'records','full')}</div></section></div>
      <section class="home-bottom">${icon('bowl')}<div><strong>今晚，做点冰箱里现有的。</strong><p>按已有食材找菜谱，也看看还缺什么。</p></div><button class="text-btn" type="button" data-page="recipes">去看菜谱 ${icon('arrow')}</button></section>`;
  }
  function previewFood(food) {
    return `<button type="button" class="food-preview" data-action="detail" data-id="${food.id}"><span class="food-symbol">${icon(food.symbol,'large')}</span><span class="food-preview-text"><span class="food-preview-title">${esc(food.name)}</span><small>${esc(food.zone)} · ${food.quantity} ${esc(food.unit)}</small></span><span class="food-expiry">${food.days===0?'今天到期':food.days+' 天后到期'}</span></button>`;
  }
  function foodsView() {
    return `${pageHead('每一份食材，都有位置。','搜索、筛选，再决定今天先用什么。',button(`${icon('clock')}记录`,'records')+button(`${icon('plus')}新增食材`,'add','primary',disabledWrite()))}<section class="filter-panel" aria-label="食材筛选"><div class="filter-row"><label class="search">${icon('search')}<input id="food-search" aria-label="搜索食材名称" placeholder="搜索食材名称" value="${esc(state.query)}"></label><select id="zone-filter" aria-label="储存分区">${['all','冷藏','变温','冷冻','常温'].map(z=>`<option value="${z}" ${state.zone===z?'selected':''}>${z==='all'?'全部分区':z}</option>`).join('')}</select><select id="expiry-filter" aria-label="到期状态">${[['all','全部到期状态'],['urgent','即将到期'],['expired','已过期'],['fresh','非临期']].map(([v,label])=>`<option value="${v}" ${state.expiry===v?'selected':''}>${label}</option>`).join('')}</select><button class="text-btn" data-action="reset-filters" type="button">重置</button></div><details class="filter-advanced"><summary>分类、标签与日期 · 完整筛选结构参考</summary><div class="form-grid"><label class="field">分类<select disabled><option>全部分类（结构示意）</option></select></label><label class="field">标签<input placeholder="如：早餐" disabled></label><label class="field">到期起始<input type="date" disabled></label><label class="field">到期截止<input type="date" disabled></label></div><p class="field-hint">本样稿可操作名称、分区、到期与排序；其余字段在正式实现保留现有能力。</p></details></section><div class="row between result-head"><span id="result-count" aria-live="polite"></span><label class="row">排序<select id="sort-picker" aria-label="食材排序" style="width:145px;min-height:40px;font-size:12px"><option value="expiry" ${state.sort==='expiry'?'selected':''}>到期日从近到远</option><option value="name" ${state.sort==='name'?'selected':''}>名称排序</option></select></label></div><section id="food-results" aria-label="食材清单"></section>`;
  }
  function updateFoodResults() {
    const foods = state.foods.filter(f => (!state.query || f.name.includes(state.query)) && (state.zone==='all'||f.zone===state.zone) && (state.expiry==='all'||state.expiry==='urgent'&&f.days>=0&&f.days<=3||state.expiry==='expired'&&f.days<0||state.expiry==='fresh'&&f.days>3)).sort((a,b)=>state.sort==='name'?a.name.localeCompare(b.name,'zh-CN'):a.days-b.days||a.id-b.id);
    $('#result-count').textContent = `共 ${foods.length} 份食材 · 全部库存 ${state.foods.length} 份`;
    $('#food-results').innerHTML = foods.length ? `<div class="food-table"><div class="food-table-head"><span>食材</span><span>储存分区</span><span>剩余数量</span><span>到期日期</span><span>保鲜状态</span><span></span></div>${foods.map(f=>`<div class="food-table-row"><div class="food-title"><span class="food-symbol">${icon(f.symbol)}</span><div>${esc(f.name)}<span class="sub-label">${esc(f.zone)} · ${esc(f.category)}</span></div></div><span class="food-zone">${esc(f.zone)}</span><span class="food-quantity">${f.quantity} ${esc(f.unit)}</span><span class="food-date">${f.date}</span><span class="food-status">${statusBadge(f)}</span><button type="button" class="text-btn food-open" data-action="detail" data-id="${f.id}" aria-label="查看${esc(f.name)}详情">${icon('chevron')}</button></div>`).join('')}</div>` : `<div class="food-table"><div class="empty-state">${icon('search')}<h2>没有找到这份食材</h2><p class="muted">换个名称，或清空当前筛选。</p>${button('清空筛选','reset-filters')}</div></div>`;
  }
  function statusBadge(food) {return `<span class="badge ${food.days<0?'danger':food.days<=3?'warning':'success'}">${food.days<0?'已过期 '+Math.abs(food.days)+' 天':food.days===0?'今天到期':food.days<=3?food.days+' 天后到期':'保鲜中'}</span>`;}
  const recipes = [
    {id:0,name:'番茄炒蛋',image:'recipe-tomato-eggs.jpg',time:'15 分钟',coverage:'已备 2 / 3 项',note:'番茄正临期，给今晚加一道家常菜。',missing:'示例缺料：小葱'},
    {id:1,name:'清炒西兰花',image:'recipe-broccoli.jpg',time:'10 分钟',coverage:'已备 1 / 2 项',note:'用一份清爽，把冰箱里的新鲜留住。',missing:'示例缺料：蒜'},
    {id:2,name:'嫩滑蒸蛋',image:'recipe-steamed-eggs.jpg',time:'20 分钟',coverage:'已备 1 / 2 项',note:'简单的食材，也能做一顿舒服的饭。',missing:'示例缺料：小葱'},
  ];
  const recipeImage = name => `../../../apps/fridge-app/assets/images/${name}`;
  function recipesView() {
    return `${pageHead('下一餐，就从冰箱开始。','先用临期食材，少一点浪费，多一点家常。')}<div class="row wrap" style="margin-bottom:22px"><span class="badge">按当前演示库存推荐</span><span class="muted" style="font-size:12px">匹配为选稿示例，正式版由真实库存计算</span></div><div class="recipe-grid">${recipes.map(r=>`<article class="recipe-card"><img src="${recipeImage(r.image)}" alt="${r.name}" loading="eager"><div class="recipe-body"><div class="row between"><h2>${r.name}</h2><span class="badge">${r.time}</span></div><p>${r.note}</p><div class="recipe-meta"><span>${r.coverage}</span><span class="muted">${r.missing}</span></div>${button(`查看做法 ${icon('arrow')}`,'recipe','',`data-id="${r.id}"`)}</div></article>`).join('')}</div>`;
  }
  function familyView() {
    return `${pageHead('一起，把日常照顾好。','切换家庭、邀请家人，每一次编辑都有清楚的边界。')}<div class="family-grid"><div><section class="panel"><div class="row between"><h2>当前家庭</h2><span class="badge">${writable()?'家庭主人':'只读成员'}</span></div><div class="family-name">${esc(state.familyName)}</div><p class="muted" style="font-size:13px">演示家庭 · 默认冰箱 · 2 位成员</p><div class="row between family-code"><div><small>家庭邀请码 · 仅演示</small><strong>XY8K2M6P</strong></div>${button(`${icon('copy')}复制`,'copy')}</div><div class="family-actions">${button(`${icon('plus')}创建家庭`,'create-family')}${button(`${icon('people')}加入家庭`,'join-family')}</div></section><section class="panel"><h2>偏好与说明</h2><div class="setting-row"><span>临期判定</span><small>跟随家庭服务配置</small></div><div class="setting-row"><span>冰箱布局</span><small>当前布局只读</small></div><div class="setting-row"><span>温度显示</span><small>储存参考，不控制设备</small></div><button class="text-btn" type="button" data-page="login">查看登录页面 ${icon('arrow')}</button></section></div><section class="panel"><div class="row between"><h2>家庭成员</h2><span class="muted" style="font-size:12px">2 人</span></div><div class="member"><span class="avatar">林</span><div><strong>小林</strong><p class="muted" style="font-size:12px">当前演示用户</p></div><span class="badge">${writable()?'OWNER':'VIEWER'}</span></div><div class="member"><span class="avatar">陈</span><div><strong>小陈</strong><p class="muted" style="font-size:12px">可查看食材和菜谱</p></div><span class="badge">VIEWER</span></div><div class="form-note">${icon('lock')}成员管理只对家庭主人开放。正式版保留调整角色、移除与转交的确认流程。</div>${button('查看成员操作示意','member','full',writable()?'style="margin-top:20px"':'disabled style="margin-top:20px"')}</section></div>`;
  }
  function recordsView() {
    return `${pageHead('厨房里的每一步，都记得。','时间线按最近操作排列，撤销能力以真实记录为准。',button('返回冰箱','home'))}<section class="panel timeline"><div class="timeline-item"><span class="timeline-dot">${icon('bowl')}</span><div><strong>${state.undone?'已撤销使用鲜牛奶':'使用鲜牛奶 0.5 盒'}</strong><small>今天 08:35 · 小林 · ${state.undone?'已恢复至扣减前数量':'早餐'} · 演示操作</small></div>${button(state.undone?'恢复操作':'撤销','undo','',disabledWrite())}</div><div class="timeline-item"><span class="timeline-dot">${icon('plus')}</span><div><strong>新增西兰花 1 棵</strong><small>昨天 18:20 · 小陈 · 冷藏</small></div><span class="muted" style="font-size:12px">新增不支持撤销</span></div><div class="timeline-item"><span class="timeline-dot">${icon('sliders')}</span><div><strong>修改鸡蛋信息</strong><small>昨天 18:15 · 小林 · 分类调整为蛋类</small></div><span class="muted" style="font-size:12px">编辑不支持撤销</span></div></section>`;
  }
  function loginView() {
    return `<div class="login-layout"><div class="login-scene"><img src="assets/kitchen-reference.png" alt="浅冷色现代家庭厨房"><span class="scene-label">${icon('fridge')}查食材，看菜谱，都容易</span></div><section class="login-form"><div class="eyebrow">XIAOYI FRIDGE</div><h1>${state.register?'给日常，一个新开始。':'欢迎回到，你的厨房。'}</h1><p>小易冰箱 · 家里的新鲜，一起照顾。</p><form id="login-form" class="form-stack"><label class="field">账号<input name="username" autocomplete="username" required placeholder="输入账号"></label><label class="field">密码<div class="row" style="gap:8px"><input id="login-password" name="password" type="password" minlength="6" autocomplete="${state.register?'new-password':'current-password'}" required placeholder="至少 6 位字符"><button class="icon-btn" type="button" data-action="password" aria-label="显示密码">${icon('eye')}</button></div></label>${state.register?'<label class="field">昵称<input name="displayName" required placeholder="家人怎么称呼你"></label>':''}<button class="btn primary full" type="submit">${state.register?'创建演示账号':'登录演示厨房'}</button></form><div class="login-footer"><button type="button" class="text-btn" data-action="register">${state.register?'已有账号，返回登录':'还没有账号？注册'}</button><button type="button" class="text-btn" data-page="home">直接体验 ${icon('arrow')}</button></div><p class="field-hint" style="margin-top:18px">仅为登录界面样稿，请使用示例输入，不会验证或保存账号。</p></section></div>`;
  }
  function componentsView() {
    const cells = [
      ['主要动作',button(`${icon('plus')}新增食材`,'add','primary'),'近黑底白字 · 单个任务一个主动作'],
      ['次要动作',button(`${icon('list')}食材清单`,'foods'),'白底细边 · 边界与文字可辨识'],
      ['悬停状态',button('保存食材','sample','primary sample-hover'),'120 ms 颜色过渡'],
      ['按下状态',button('保存食材','sample','primary sample-pressed'),'更深底色 · 1 px 下移'],
      ['键盘焦点',button('保存食材','sample','primary sample-focus'),'2 px 灰蓝外环 + 2 px 间距'],
      ['提交中','<button class="btn primary" type="button" disabled><span class="spinner"></span>正在保存…</button>','锁定相关写操作 · 保持按钮宽度'],
      ['只读 / 禁用',button('新增食材','sample','', 'disabled'),'你是只读成员，编辑需要家庭主人授权'],
      ['成功反馈',`<div class="demo-alert demo-success">${icon('check')} 已保存食材（演示）</div>`,'服务端确认后才更新正式库存'],
      ['失败恢复','<div class="demo-alert">保存失败，已保留填写内容。</div>','在“审查控制”模拟失败后可重试'],
      ['危险操作',button(`${icon('trash')}丢弃食材`,'sample-discard','danger'),'先确认对象和后果，再执行'],
      ['分区 / 开合','<button class="door-button" type="button" aria-pressed="true" data-part="left">左门 · 已开启</button>','多扇门独立高亮，概览不冒充开门'],
      ['关闭 / 返回','<button class="icon-btn" type="button" data-page="home" aria-label="返回冰箱">'+icon('close')+'</button>','44 px 命中区 · 关闭后恢复焦点'],
    ];
    return `${pageHead('每一次点击，都有回应。','按钮层级、状态与错误反馈，三套方案遵循同一套规则。')}<p class="components-intro">悬停、按下与焦点为固定审查状态。真实表单反馈可在新增食材中操作。</p><div class="component-grid">${cells.map(([title,content,note])=>`<section class="component-cell"><h3>${title}</h3>${content}<p>${note}</p></section>`).join('')}</div>`;
  }
  function toast(message) {
    clearTimeout(toastTimer);$('#toast').textContent=message;$('#toast').hidden=false;
    toastTimer=setTimeout(()=>{$('#toast').hidden=true;},4500);
  }
  function navigate(page) {
    if(!validPages.includes(page))return;
    state.page=page;render();window.scrollTo(0,0);
  }
  function openModal(type,title,body,footer='') {
    if(!modal.open)opener=document.activeElement;state.modalType=type;state.dirty=false;
    modal.innerHTML=`<header class="modal-header"><div><small>小易冰箱 · 设计样稿</small><h2>${title}</h2></div><button class="icon-btn" type="button" data-action="close-modal" aria-label="关闭面板">${icon('close')}</button></header>${body}${footer}`;
    if(!modal.open)modal.showModal();
    modal.scrollTop=0;
  }
  function closeModal() {
    modal.close();state.modalType=null;state.dirty=false;state.pending=false;
    if(opener?.isConnected)opener.focus();
  }
  function requestClose() {
    if(state.pending){toast('演示保存正在进行，请稍候。');return;}
    if(state.dirty){confirm('放弃这次修改？','填写的内容还没有保存。可以继续填写，或放弃这次修改。','放弃修改',()=>closeModal(),'继续填写');return;}
    closeModal();
  }
  function confirm(title,message,label,onConfirm,cancelLabel='取消') {
    confirmDialog.innerHTML=`<h2>${title}</h2><p>${message}</p><div class="row">${button(cancelLabel,'cancel-confirm')}${button(label,'accept-confirm','danger-fill')}</div>`;
    confirmDialog.showModal();
    $('[data-action="cancel-confirm"]',confirmDialog).focus();
    $('[data-action="accept-confirm"]',confirmDialog).onclick=()=>{confirmDialog.close();onConfirm();};
  }
  function addForm(food=null) {
    if(!writable()){toast('只读成员不能修改食材。');return;}
    state.editId=food?.id||null;
    const options=(values,current)=>values.map(v=>`<option ${v===current?'selected':''}>${v}</option>`).join('');
    const field=(label,name,control,extra='')=>`<label class="field ${extra}" data-field="${name}"><span>${label}</span>${control}<span class="field-error" role="alert"></span></label>`;
    openModal('add',food?'编辑食材':'新增一份新鲜',`<form id="food-form" novalidate><div class="modal-content"><div class="form-error" role="alert"></div><div class="form-grid">${field('食材名称 <span class="required">*</span>','name',`<input name="name" placeholder="例如：鲜牛奶" maxlength="30" value="${esc(food?.name||'')}" required>`,'span-2')}${field('分类','category',`<select name="category">${options(['蔬菜','水果','肉类','水产','蛋类','奶制品','主食','豆制品','调味品','饮品','熟食','其他'],food?.category||'蔬菜')}</select>`)}${field('储存分区','zone',`<select name="zone">${options(['冷藏','变温','冷冻','常温'],food?.zone||'冷藏')}</select>`)}${field('数量 <span class="required">*</span>','quantity',`<input name="quantity" type="number" inputmode="decimal" step="0.001" min="0.001" max="999999" value="${food?.quantity||1}" required>`)}${field('单位','unit',`<select name="unit">${options(['份','个','盒','袋','棵','克','毫升'],food?.unit||'份')}</select>`)}${field('购买日期','purchase','<input name="purchase" type="date" value="2026-11-10">')}${field('到期日期 <span class="required">*</span>','date',`<input name="date" type="date" value="${food?.date||'2026-11-13'}" required>`)}</div><div class="form-note">${icon('info')}保存到「${esc(state.familyName)} / 默认冰箱」。本次为界面演示，刷新后重置。</div></div><footer class="modal-footer">${button('取消','close-modal')}<button class="btn primary" type="submit" id="save-food">保存食材</button></footer></form>`);
    if(food)$('[name="purchase"]',modal).value=food.purchase||'2026-11-01';
    state.initialForm = new URLSearchParams(new FormData($('#food-form'))).toString();
  }
  function detail(id) {
    const f=state.foods.find(f=>f.id===Number(id));if(!f)return;
    state.selectedId=f.id;
    openModal('detail','食材详情',`<div class="modal-content"><div class="detail-hero"><span class="food-symbol">${icon(f.symbol,'large')}</span><div><h2>${esc(f.name)}</h2><div class="detail-number">${f.quantity} <small>${esc(f.unit)}</small></div></div><div style="margin-left:auto">${statusBadge(f)}</div></div><dl class="detail-list"><div><dt>储存分区</dt><dd>${esc(f.zone)}</dd></div><div><dt>食材分类</dt><dd>${esc(f.category)}</dd></div><div><dt>到期日期</dt><dd>${f.date}</dd></div><div><dt>当前家庭</dt><dd>${esc(state.familyName)}</dd></div></dl>${f.days<0?'<div class="demo-alert" style="margin-top:20px">这份食材已过期，请检查后再处理，不纳入临期做饭推荐。</div>':''}<div class="detail-actions">${button('使用食材','use','primary',disabledWrite())}${button('移动分区','move','',disabledWrite())}</div>${button('编辑食材信息','edit','full',disabledWrite())}<div class="detail-danger"><div><strong>不再保留这份食材</strong><p>丢弃前再次确认，操作会写入记录。</p></div>${button('丢弃','discard','danger',disabledWrite())}</div>${!writable()?'<p class="field-hint" style="margin-top:20px">只读成员不能使用、移动或修改食材。</p>':''}</div>`);
  }
  function useOrMove(type) {
    if(!writable())return;
    const f=state.foods.find(f=>f.id===state.selectedId);if(!f)return;
    if(type==='use'&&f.days<0){toast('这份食材已过期，请先检查处理。');return;}
    openModal(type,type==='use'?'使用多少食材？':'移到哪个分区？',`<form id="operation-form"><div class="modal-content"><div class="detail-hero"><span class="food-symbol">${icon(f.symbol)}</span><div><h2>${esc(f.name)}</h2><p class="muted">当前 ${f.quantity} ${esc(f.unit)} · ${esc(f.zone)}</p></div></div>${type==='use'?`<label class="field">本次使用量（${esc(f.unit)}）<input name="amount" type="number" min="0.001" step="0.001" max="${f.quantity}" value="${Math.min(1,f.quantity)}" required></label><p class="field-hint" style="margin-top:12px">最多使用 ${f.quantity} ${esc(f.unit)}，数量最多三位小数。</p>`:`<label class="field">目标分区<select name="zone">${['冷藏','变温','冷冻','常温'].map(z=>`<option ${z===f.zone?'selected':''}>${z}</option>`).join('')}</select></label>`}</div><footer class="modal-footer">${button('取消','close-modal')}<button class="btn primary" type="submit">${type==='use'?'确认使用':'确认移动'}</button></footer></form>`);
  }
  function recipeDetail(id) {
    const r=recipes[Number(id)]||recipes[0];state.recipeId=r.id;
    openModal('recipe',r.name,`<div class="modal-content"><img class="recipe-detail-photo" src="${recipeImage(r.image)}" alt="${r.name}"><div class="row between"><span class="badge">${r.time}</span><span class="muted">${r.coverage}</span></div><h3 style="margin-top:22px">准备食材</h3><ul class="ingredients"><li>${r.id===0?'番茄 2 个、鸡蛋 2 个':r.id===1?'西兰花 1 棵':'鸡蛋 2 个'}</li><li>${r.missing} · 按实际需要准备</li></ul><h3 style="margin-top:20px">家常做法 · 示例</h3><ol class="steps"><li>清洗并处理食材，提前准备好所需用具。</li><li>按食材顺序烹饪，注意火候与用量。</li><li>完成后调味装盘，确认本次实际使用量。</li></ol><p class="field-hint">此处为版式示例，正式版继续读取现有菜谱详情和步骤。</p></div>`,`<footer class="modal-footer">${button('关闭','close-modal')}${button('用现有食材做这道菜','cook','primary',disabledWrite())}</footer>`);
  }
  function cookForm() {
    if(!writable())return;
    const available=state.foods.filter(f=>f.days>=0&&[2,3,4].includes(f.id));
    openModal('cook','确认这次做饭用量',`<form id="cook-form"><div class="modal-content"><p class="muted" style="font-size:13px;margin-bottom:18px">逐项选择实际使用的食材。样稿只演示确认，不改变真实库存。</p>${available.map(f=>`<div class="check-row"><label><input type="checkbox" name="food-${f.id}" checked>${esc(f.name)}</label><input type="number" aria-label="${esc(f.name)}使用量" min="0.001" max="${f.quantity}" step="0.001" value="1"><small>${f.unit}</small></div>`).join('')}<div class="form-note">${icon('info')}正式实现继续使用既有幂等请求和版本校验，不能重复扣减。</div></div><footer class="modal-footer">${button('返回','close-modal')}<button class="btn primary" type="submit">确认做饭（演示）</button></footer></form>`);
  }
  function familyForm(join) {
    state.joinFamily=join;
    openModal('family',join?'加入一个家庭':'创建你的家庭',`<form id="family-form"><div class="modal-content"><label class="field">${join?'家庭邀请码':'家庭名称'}<input name="family" required ${join?'pattern="[A-Za-z0-9]{8}" maxlength="8" placeholder="输入 8 位演示邀请码"':'maxlength="30" placeholder="例如：林间小家"'}></label><div class="form-note">${icon('home')}${join?'加入后默认只读成员。':'创建家庭时同时初始化默认冰箱。'}本面板仅演示交互。</div></div><footer class="modal-footer">${button('取消','close-modal')}<button class="btn primary" type="submit">${join?'加入演示家庭':'创建演示家庭'}</button></footer></form>`);
  }
  document.addEventListener('click',event=>{
    const navButton=event.target.closest('[data-page]');if(navButton){navigate(navButton.dataset.page);return;}
    const part=event.target.closest('[data-part]');if(part){const key=part.dataset.part;state.openParts.has(key)?state.openParts.delete(key):state.openParts.add(key);document.querySelectorAll(`[data-part="${key}"]`).forEach(b=>b.setAttribute('aria-pressed',String(state.openParts.has(key))));return;}
    const control=event.target.closest('[data-action]');if(!control||control.disabled)return;
    const action=control.dataset.action;
    if(action==='accept-confirm')return;
    const actions={home:()=>navigate('home'),foods:()=>navigate('foods'),records:()=>navigate('records'),add:()=>addForm(),detail:()=>detail(control.dataset.id),recipe:()=>recipeDetail(control.dataset.id),'close-modal':requestClose,'cancel-confirm':()=>confirmDialog.close(),
      'close-all':()=>{state.openParts.clear();document.querySelectorAll('[data-part]').forEach(b=>b.setAttribute('aria-pressed','false'));},
      'reset-scene':()=>toast('已回到默认视角（样稿示意，参考图保持静态）。'),
      cold:()=>{state.zone='冷藏';navigate('foods');},
      'reset-filters':()=>{state.query='';state.zone='all';state.expiry='all';state.sort='expiry';render();},
      edit:()=>addForm(state.foods.find(f=>f.id===state.selectedId)),use:()=>useOrMove('use'),move:()=>useOrMove('move'),
      discard:()=>{if(!writable())return;const f=state.foods.find(f=>f.id===state.selectedId);if(!f)return;confirm('丢弃这份食材？',`将丢弃「${esc(f.name)}」${f.quantity} ${esc(f.unit)}。正式版会记录操作，并按真实记录提供撤销。`,'确认丢弃',()=>{state.foods=state.foods.filter(item=>item.id!==f.id);closeModal();render();toast('已丢弃食材（演示）· 可在正式版记录中查找。');});},
      'sample-discard':()=>confirm('丢弃这份食材？','将丢弃鲜牛奶 1 盒。此处只演示危险操作的确认层。','确认丢弃',()=>toast('已确认丢弃（按钮样稿）。')),
      undo:()=>{if(!writable())return;state.undone=!state.undone;render();toast(state.undone?'已撤销这条操作（演示）。':'已恢复这条操作（演示）。');},
      password:()=>{const input=$('#login-password');input.type=input.type==='password'?'text':'password';control.setAttribute('aria-label',input.type==='password'?'显示密码':'隐藏密码');},
      register:()=>{state.register=!state.register;render();},
      copy:async()=>{try{await navigator.clipboard.writeText('XY8K2M6P');toast('已复制演示邀请码。');}catch{toast('复制不可用，请手动复制：XY8K2M6P');}},
      'create-family':()=>familyForm(false),'join-family':()=>familyForm(true),
      member:()=>openModal('member','成员操作示意',`<div class="modal-content"><h3>小陈 · 当前 VIEWER</h3><p class="muted" style="margin:12px 0 22px">可查看食材与菜谱，不能修改库存。</p>${button('调整为可编辑成员','sample-role','full')}${button('移除成员','sample-remove','danger full','style="margin-top:12px"')}<p class="field-hint" style="margin-top:18px">正式版仅家庭主人可操作，服务端仍会校验权限。</p></div>`),
      'sample-role':()=>confirm('调整成员权限？','把小陈从只读成员调整为可编辑成员后，对方可以修改家庭食材。','确认调整',()=>toast('已确认权限调整（演示，未修改真实成员）。')),
      'sample-remove':()=>confirm('移除这位成员？','小陈将失去访问此家庭库存的权限。此处仅演示确认界面。','确认移除',()=>toast('已确认移除（演示）。')),
      cook:cookForm,sample:()=>toast('这是固定按钮状态示例。'),
    };actions[action]?.();
  });
  document.addEventListener('input',event=>{
    if(event.target.id==='food-search'){state.query=event.target.value;updateFoodResults();}
    const form=event.target.closest('#food-form');if(form)state.dirty=new URLSearchParams(new FormData(form)).toString()!==state.initialForm;
  });
  document.addEventListener('change',event=>{
    if(event.target.id==='scheme-picker'){location.href=`prototype.html?scheme=${event.target.value}&page=${state.page}`;return;}
    if(event.target.id==='role-picker'){state.role=event.target.value;render();return;}
    if(event.target.id==='zone-filter')state.zone=event.target.value;
    if(event.target.id==='expiry-filter')state.expiry=event.target.value;
    if(event.target.id==='sort-picker')state.sort=event.target.value;
    if(['zone-filter','expiry-filter','sort-picker'].includes(event.target.id))updateFoodResults();
    const form=event.target.closest('#food-form');if(form)state.dirty=new URLSearchParams(new FormData(form)).toString()!==state.initialForm;
  });
  document.addEventListener('submit',async event=>{
    const form=event.target;event.preventDefault();
    if(form.id==='food-form'){
      if(!writable()||state.pending)return;
      const data=Object.fromEntries(new FormData(form));
      form.querySelectorAll('.has-error').forEach(el=>el.classList.remove('has-error'));
      const errors={};
      if(!data.name.trim())errors.name='请填写食材名称。';
      if(!/^\d+(\.\d{1,3})?$/.test(data.quantity)||Number(data.quantity)<=0||Number(data.quantity)>999999)errors.quantity='数量须大于 0，最多三位小数且不超过 999999。';
      if(!data.date)errors.date='请选择到期日期。';
      if(data.purchase&&data.date&&data.date<data.purchase)errors.date='到期日期不能早于购买日期。';
      for(const [key,message]of Object.entries(errors)){const field=$(`[data-field="${key}"]`,form);field.classList.add('has-error');$('.field-error',field).textContent=message;}
      if(Object.keys(errors).length){$('input,select',$(`[data-field="${Object.keys(errors)[0]}"]`,form)).focus();return;}
      const save=$('#save-food');const shouldFail=$('#fail-next').checked;$('#fail-next').checked=false;
      state.pending=true;save.disabled=true;save.innerHTML='<span class="spinner"></span>正在保存…';$('.form-error',form).classList.remove('visible');
      form.querySelectorAll('input,select,textarea').forEach(e=>e.disabled=true);
      modal.querySelectorAll('[data-action="close-modal"]').forEach(b=>b.disabled=true);
      await new Promise(resolve=>setTimeout(resolve,750));
      if(shouldFail){state.pending=false;form.querySelectorAll('input,select,textarea').forEach(e=>e.disabled=false);save.disabled=false;save.textContent='重新保存';modal.querySelectorAll('[data-action="close-modal"]').forEach(b=>b.disabled=false);$('.form-error',form).textContent='保存失败（模拟）。填写内容已保留，请重试。';$('.form-error',form).classList.add('visible');return;}
      const id=state.editId||state.nextId++;
      const existing=state.foods.find(f=>f.id===id);
      const food={id,name:data.name.trim(),quantity:Number(data.quantity),unit:data.unit,zone:data.zone,category:data.category,purchase:data.purchase,date:data.date,days:Math.round((Date.parse(data.date+'T00:00:00Z')-Date.parse('2026-11-10T00:00:00Z'))/86400000),symbol:existing?.symbol||'pantry'};
      state.foods=existing?state.foods.map(f=>f.id===id?food:f):[...state.foods,food];state.dirty=false;closeModal();render();$('[data-action="add"]')?.focus();toast('已保存食材（演示）· 刷新后重置。');
    }else if(form.id==='operation-form'){
      if(!writable())return;const data=Object.fromEntries(new FormData(form));const food=state.foods.find(f=>f.id===state.selectedId);if(!food)return;
      if(state.modalType==='use'){const amount=Number(data.amount);if(!/^\d+(\.\d{1,3})?$/.test(data.amount)||amount<=0||amount>food.quantity){toast('请填写有效数量，最多三位小数且不能超过库存。');return;}food.quantity=Number((food.quantity-amount).toFixed(3));}else food.zone=data.zone;
      closeModal();render();toast('已更新食材（演示）。');
    }else if(form.id==='login-form'){navigate('home');toast('已进入演示厨房，未登录真实账号。');
    }else if(form.id==='family-form'){const value=new FormData(form).get('family');state.familyName=state.joinFamily?'加入的演示家庭':value;closeModal();navigate('family');toast('已更新演示家庭名称；当前食材仍为选稿示例。');
    }else if(form.id==='cook-form'){if(!writable())return;if(!form.querySelector('input[type=checkbox]:checked')){toast('请至少选择一份食材。');return;}closeModal();toast('已确认做饭用量（样稿演示，未扣减库存）。');}
  });
  modal.addEventListener('cancel',event=>{event.preventDefault();requestClose();});
  modal.addEventListener('click',event=>{if(event.target===modal){const r=modal.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)requestClose();}});
  render();
  window.reviewState=()=>({scheme:state.scheme,page:state.page,role:state.role,foodCount:state.foods.length,pending:state.pending,dirty:state.dirty,openParts:[...state.openParts]});
})();
