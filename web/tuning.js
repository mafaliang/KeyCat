// Behaviour settings the user can tune in the 调节 window (settings.html). The cat reads the
// current values from `TUNING`; the app stores only the ones that differ from `def` and pushes them
// in with `cat.options({ tune: {...} })`. Values are in the units shown in the window. A group's
// `switch` names the toggle that greys out the rest of the group; `fmt` overrides how a value shows.
'use strict';
const hourLabel = h => `${String(Math.floor(h) % 24).padStart(2, '0')}:${h % 1 ? '30' : '00'}`;
const TUNING_SCHEMA = [
  { group: '不耐烦（尾巴捶桌）', switch: 'annoyOn', items: [
    { key: 'annoyOn', label: '会不耐烦', type: 'toggle', def: true,
      hint: '关掉后不会再生气，也不会甩尾巴捶桌。' },
    { key: 'typeRate', label: '打字多快会烦', type: 'range', min: 4, max: 20, step: 1, def: 9, unit: '键/秒',
      hint: '持续快于这个速度，烦躁会慢慢累积。' },
    { key: 'mashKeys', label: '几个键一起按算乱拍', type: 'range', min: 3, max: 8, step: 1, def: 4, unit: '个',
      hint: '0.15 秒内按下这么多键，算一次乱拍，马上烦一大截。' },
    { key: 'petLimit', label: '摸头多久会烦', type: 'range', min: 2, max: 30, step: 1, def: 4, unit: '秒',
      hint: '摸了这么久还没呼噜起来就会烦，呼噜起来以后怎么摸都不烦。越熟它越能忍，每升一级多忍四分之一。' },
    { key: 'wakeAnnoy', label: '被吵醒有多烦', type: 'range', min: 0, max: 100, step: 5, def: 35, unit: '%',
      hint: '睡着时被键盘或鼠标吵醒，烦躁一下子加这么多。' },
    { key: 'crossAt', label: '烦到多少开始捶桌', type: 'range', min: 20, max: 100, step: 5, def: 60, unit: '%' },
    { key: 'calmRate', label: '消气速度', type: 'range', min: 2, max: 50, step: 1, def: 10, unit: '%/秒',
      hint: '安静 2 秒后，每秒消掉这么多烦躁。' },
    { key: 'thumpRate', label: '捶桌节奏', type: 'range', min: 1, max: 5, step: 0.1, def: 2.6, unit: '下/秒' },
  ] },
  { group: '好奇（快速移动鼠标）', switch: 'curiousOn', items: [
    { key: 'curiousOn', label: '会好奇', type: 'toggle', def: true,
      hint: '快速移动鼠标时，猫瞪大眼睛、瞳孔放大，竖起耳朵盯着光标。' },
    { key: 'curiousSpeed', label: '鼠标多快会好奇', type: 'range', min: 300, max: 4000, step: 100, def: 1400, unit: '点/秒' },
    { key: 'pupilSize', label: '好奇时瞳孔多大', type: 'range', min: 100, max: 300, step: 10, def: 230, unit: '%',
      hint: '相对平时竖瞳的宽度。' },
    { key: 'curiousHold', label: '好奇持续多久', type: 'range', min: 0.5, max: 6, step: 0.5, def: 2, unit: '秒',
      hint: '鼠标停下后，还要盯这么久才放松。' },
  ] },
  { group: '亲近', items: [
    { key: 'purrAfter', label: '摸头多久开始呼噜', type: 'range', min: 0.5, max: 10, step: 0.5, def: 1.5, unit: '秒',
      hint: '呼噜时两只前爪轮流踩奶。声音要在菜单里打开。' },
    { key: 'blinkBack', label: '回应慢眨眼的概率', type: 'range', min: 0, max: 100, step: 5, def: 60, unit: '%',
      hint: '双击猫头，就是对它慢眨眼。越熟越容易回应。' },
    { key: 'needyAfter', label: '只用鼠标多久来找存在感', type: 'range', min: 0, max: 30, step: 1, def: 3, unit: '分钟',
      hint: '它自己按一下键盘或用尾巴拍空格，再看着你。0 表示不会。' },
  ] },
  { group: '睡觉', items: [
    { key: 'sprawlAfter', label: '睡多久后霸占键盘', type: 'range', min: 0, max: 30, step: 1, def: 3, unit: '分钟',
      hint: '睡着后再过这么久没人理，它会走到键盘上趴下。0 表示不会。' },
  ] },
  { group: '照顾你', items: [
    { key: 'breakAfter', label: '连续工作多久提醒休息', type: 'range', min: 0, max: 120, step: 5, def: 50, unit: '分钟',
      hint: '它会趴到键盘上不让你打字，离开一会儿算休息过了，摸摸它就再给你 10 分钟。中间停 3 分钟以上算休息过。0 表示不提醒。' },
    { key: 'nightOn', label: '深夜催睡', type: 'toggle', def: true,
      hint: '过了下面的时间你还在用电脑，它会犯困、打哈欠，偶尔催你睡觉。' },
    { key: 'nightAt', label: '几点算深夜', type: 'range', min: 21, max: 26, step: 0.5, def: 23.5, fmt: hourLabel },
  ] },
  { group: '番茄钟', items: [
    { key: 'pomoFocus', label: '专注多久', type: 'range', min: 5, max: 60, step: 5, def: 25, unit: '分钟',
      hint: '在菜单里开始。专注时猫安静陪着，不做小动作。' },
    { key: 'pomoBreak', label: '休息多久', type: 'range', min: 1, max: 30, step: 1, def: 5, unit: '分钟' },
  ] },
];
const TUNING = {};
for (const g of TUNING_SCHEMA) for (const it of g.items) TUNING[it.key] = it.def;

// Personalities: each is a set of the values above (the rest stay at their defaults).
const TUNING_PRESETS = [
  { name: '默认', hint: '', values: {} },
  { name: '高冷', hint: '不太黏人，摸久了就烦，很少回应你', values: {
    petLimit: 3, purrAfter: 4, blinkBack: 25, needyAfter: 0, typeRate: 8, curiousSpeed: 2000 } },
  { name: '粘人', hint: '怎么摸都行，很快呼噜，常来找你', values: {
    petLimit: 30, purrAfter: 0.5, blinkBack: 95, needyAfter: 2, wakeAnnoy: 0, calmRate: 30 } },
  { name: '暴躁', hint: '一点就着，消气还慢', values: {
    typeRate: 6, mashKeys: 3, petLimit: 2, wakeAnnoy: 80, crossAt: 40, calmRate: 5, thumpRate: 3.5, blinkBack: 35 } },
  { name: '胆小', hint: '容易被吵醒和惊到，一点动静就瞪圆眼睛', values: {
    wakeAnnoy: 60, mashKeys: 3, pupilSize: 290, curiousSpeed: 900, blinkBack: 50, curiousHold: 4 } },
];
