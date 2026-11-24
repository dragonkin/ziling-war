/* 字灵图鉴 · 字表
   多字族结构：每个字族一种构字规律。
   - 部首族（义符相同）：氵 = 意思都和水有关
   - 声符族（声符相同）：青 = 读音相近，意思由前面的部首决定（这才是汉字的大头）

   每字含：情境 / 拆形 / 认义 / 组词四步所需数据
   q3.options = 图（考"懂不懂"），q4.options = 字（考同音字辨识，运行时自动打乱）
   parts = [义符, 声符]；notes = 拆形页的两句讲解 */

window.CHAR_DATA = {
  families: [
    {
      id: 'shui',
      name: '水之族',
      radical: '氵',
      shapePart: '氵',
      intro: '「氵」叫三点水。这一家的字，意思都和水有关。',
      chars: [
        {
          c: '江', py: 'jiāng', emoji: '🌊',
          scene: '长江是中国最长的一条江。',
          parts: ['氵', '工'],
          notes: ['「氵」表示和水有关', '「工」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「江」？',
            options: [{ e: '🌊', l: '大江' }, { e: '🏔️', l: '高山' }, { e: '🌳', l: '大树' }],
            answer: 0
          },
          q4: { prompt: '长 ___', options: ['江', '姜', '将'], answer: 0 }
        },
        {
          c: '河', py: 'hé', emoji: '🏞️',
          scene: '小河里游着好多小鱼。',
          parts: ['氵', '可'],
          notes: ['「氵」表示和水有关', '「可」提示读音'],
          q3: {
            prompt: '哪一张图是「河」？',
            options: [{ e: '🏞️', l: '小河' }, { e: '🏜️', l: '沙漠' }, { e: '🌋', l: '火山' }],
            answer: 0
          },
          q4: { prompt: '小 ___', options: ['河', '禾', '喝'], answer: 0 }
        },
        {
          c: '池', py: 'chí', emoji: '🪷',
          scene: '池塘里开满了荷花。',
          parts: ['氵', '也'],
          notes: ['「氵」表示和水有关', '「也」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「池」？',
            options: [{ e: '🪷', l: '池塘' }, { e: '🏜️', l: '沙漠' }, { e: '⛰️', l: '山' }],
            answer: 0
          },
          q4: { prompt: '游泳 ___', options: ['池', '迟', '持'], answer: 0 }
        },
        {
          c: '海', py: 'hǎi', emoji: '🐳',
          scene: '大海一望无边，浪花一朵朵。',
          parts: ['氵', '每'],
          notes: ['「氵」表示和水有关', '「每」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「海」？',
            options: [{ e: '🐳', l: '大海' }, { e: '🏞️', l: '小河' }, { e: '🕳️', l: '井' }],
            answer: 0
          },
          q4: { prompt: '大 ___', options: ['海', '孩', '每'], answer: 0 }
        },
        {
          c: '洗', py: 'xǐ', emoji: '🧼',
          scene: '吃饭前要洗手。',
          parts: ['氵', '先'],
          notes: ['「氵」表示和水有关', '「先」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「洗」？',
            options: [{ e: '🧼', l: '洗手' }, { e: '😴', l: '睡觉' }, { e: '🍚', l: '吃饭' }],
            answer: 0
          },
          q4: { prompt: '___ 手', options: ['洗', '喜', '系'], answer: 0 }
        },
        {
          c: '汗', py: 'hàn', emoji: '💦',
          scene: '跑完步，头上出了好多汗。',
          parts: ['氵', '干'],
          notes: ['「氵」表示和水有关', '「干」提示读音'],
          q3: {
            prompt: '哪一张图是「汗」？',
            options: [{ e: '💦', l: '出汗' }, { e: '❄️', l: '下雪' }, { e: '☀️', l: '太阳' }],
            answer: 0
          },
          q4: { prompt: '出 ___', options: ['汗', '汉', '旱'], answer: 0 }
        },
        {
          c: '泳', py: 'yǒng', emoji: '🏊',
          scene: '夏天我最喜欢去游泳。',
          parts: ['氵', '永'],
          notes: ['「氵」表示和水有关', '「永」提示读音'],
          q3: {
            prompt: '哪一张图是「泳」？',
            options: [{ e: '🏊', l: '游泳' }, { e: '🚴', l: '骑车' }, { e: '🏃', l: '跑步' }],
            answer: 0
          },
          q4: { prompt: '游 ___', options: ['泳', '勇', '永'], answer: 0 }
        },
        {
          c: '渴', py: 'kě', emoji: '🥤',
          scene: '跑了很久，我好渴，想喝水。',
          parts: ['氵', '曷'],
          notes: ['「氵」表示和水有关', '「曷」提示读音'],
          q3: {
            prompt: '哪一张图是「渴」？',
            options: [{ e: '🥤', l: '口渴' }, { e: '🍎', l: '苹果' }, { e: '🎈', l: '气球' }],
            answer: 0
          },
          q4: { prompt: '口 ___', options: ['渴', '可', '课'], answer: 0 }
        }
      ]
    },

    {
      id: 'qing',
      name: '青之家族',
      radical: '青',
      soundPart: '青',
      intro: '这一家都带着「青」。意思由前面的部首决定，读音由「青」提示——一个「青」，能变出好多字。',
      chars: [
        {
          c: '青', py: 'qīng', emoji: '🌿', isRoot: true,
          scene: '春天到了，青草绿油油的。',
          parts: ['青'],
          notes: ['它是这一家的根'],
          q3: {
            prompt: '哪一张图是「青」？',
            options: [{ e: '🌿', l: '青草' }, { e: '🍂', l: '落叶' }, { e: '🌸', l: '桃花' }],
            answer: 0
          },
          q4: { prompt: '___ 草', options: ['青', '清', '晴'], answer: 0 }
        },
        {
          c: '清', py: 'qīng', emoji: '💧',
          scene: '小河里的水很清，能看见水底的小鱼。',
          parts: ['氵', '青'],
          notes: ['「氵」表示和水有关', '「青」提示读音（qīng）'],
          q3: {
            prompt: '哪一张图是「清」？',
            options: [{ e: '💧', l: '清清的水' }, { e: '🌫️', l: '浑浊的水' }, { e: '🔥', l: '很烫' }],
            answer: 0
          },
          q4: { prompt: '___ 水', options: ['清', '请', '晴'], answer: 0 }
        },
        {
          c: '晴', py: 'qíng', emoji: '☀️',
          scene: '今天是晴天，太阳出来了。',
          parts: ['日', '青'],
          notes: ['「日」表示和太阳有关', '「青」提示读音（qíng）'],
          q3: {
            prompt: '哪一张图是「晴」？',
            options: [{ e: '☀️', l: '晴天' }, { e: '🌧️', l: '下雨' }, { e: '🌨️', l: '下雪' }],
            answer: 0
          },
          q4: { prompt: '___ 天', options: ['晴', '情', '清'], answer: 0 }
        },
        {
          c: '情', py: 'qíng', emoji: '❤️',
          scene: '今天心情特别好，因为要出去玩。',
          parts: ['忄', '青'],
          notes: ['「忄」表示和心情有关', '「青」提示读音（qíng）'],
          q3: {
            prompt: '哪一张图是「情」？',
            options: [{ e: '😊', l: '好心情' }, { e: '🍚', l: '吃饭' }, { e: '🏃', l: '跑步' }],
            answer: 0
          },
          q4: { prompt: '心 ___', options: ['情', '晴', '清'], answer: 0 }
        },
        {
          c: '请', py: 'qǐng', emoji: '🙏',
          scene: '「请你帮帮我。」这句话要好好地说。',
          parts: ['讠', '青'],
          notes: ['「讠」表示和说话有关', '「青」提示读音（qǐng）'],
          q3: {
            prompt: '哪一张图是「请」？',
            options: [{ e: '🙏', l: '请人帮忙' }, { e: '🏃', l: '跑步' }, { e: '🍎', l: '苹果' }],
            answer: 0
          },
          q4: { prompt: '___ 坐', options: ['请', '清', '晴'], answer: 0 }
        },
        {
          c: '睛', py: 'jīng', emoji: '👁️',
          scene: '小猴子有一双亮晶晶的眼睛。',
          parts: ['目', '青'],
          notes: ['「目」表示和眼睛有关', '它和「青」长得像，但读 jīng'], 
          q3: {
            prompt: '哪一张图是「睛」？',
            options: [{ e: '👁️', l: '眼睛' }, { e: '👂', l: '耳朵' }, { e: '👄', l: '嘴巴' }],
            answer: 0
          },
          q4: { prompt: '眼 ___', options: ['睛', '晴', '清'], answer: 0 }
        }
      ]
    },

    {
      id: 'shou',
      name: '手之族',
      radical: '扌',
      shapePart: '扌',
      intro: '「扌」是「手」变来的。这一家的字，全是手上的动作。',
      chars: [
        {
          c: '打', py: 'dǎ', emoji: '🥁',
          scene: '爸爸在打鼓，咚咚咚。',
          parts: ['扌', '丁'],
          notes: ['「扌」表示和手的动作有关', '「丁」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「打」？',
            options: [{ e: '🥁', l: '打鼓' }, { e: '🍚', l: '吃饭' }, { e: '😴', l: '睡觉' }],
            answer: 0
          },
          q4: { prompt: '___ 鼓', options: ['打', '拿', '搭'], answer: 0 }
        },
        {
          c: '拉', py: 'lā', emoji: '🪢',
          scene: '我们两个一起拉绳子。',
          parts: ['扌', '立'],
          notes: ['「扌」表示和手的动作有关', '「立」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「拉」？',
            options: [{ e: '🪢', l: '拉绳子' }, { e: '🏊', l: '游泳' }, { e: '🍎', l: '苹果' }],
            answer: 0
          },
          q4: { prompt: '___ 开', options: ['拉', '啦', '腊'], answer: 0 }
        },
        {
          c: '抱', py: 'bào', emoji: '🧸',
          scene: '妈妈抱着小宝宝。',
          parts: ['扌', '包'],
          notes: ['「扌」表示和手的动作有关', '「包」提示读音'],
          q3: {
            prompt: '哪一张图是「抱」？',
            options: [{ e: '🧸', l: '抱娃娃' }, { e: '🏃', l: '跑步' }, { e: '🌧️', l: '下雨' }],
            answer: 0
          },
          q4: { prompt: '___ 着', options: ['抱', '报', '饱'], answer: 0 }
        },
        {
          c: '推', py: 'tuī', emoji: '🛒',
          scene: '我们一起推小车。',
          parts: ['扌', '隹'],
          notes: ['「扌」表示和手的动作有关', '「隹」提示读音'],
          q3: {
            prompt: '哪一张图是「推」？',
            options: [{ e: '🛒', l: '推车' }, { e: '😴', l: '睡觉' }, { e: '🎈', l: '气球' }],
            answer: 0
          },
          q4: { prompt: '___ 车', options: ['推', '堆', '腿'], answer: 0 }
        },
        {
          c: '拍', py: 'pāi', emoji: '🏓',
          scene: '他拍皮球拍得真好。',
          parts: ['扌', '白'],
          notes: ['「扌」表示和手的动作有关', '「白」提示读音'],
          q3: {
            prompt: '哪一张图是「拍」？',
            options: [{ e: '🏓', l: '拍球' }, { e: '📖', l: '看书' }, { e: '🍚', l: '吃饭' }],
            answer: 0
          },
          q4: { prompt: '___ 手', options: ['拍', '排', '派'], answer: 0 }
        },
        {
          c: '提', py: 'tí', emoji: '🛍️',
          scene: '我帮妈妈提东西。',
          parts: ['扌', '是'],
          notes: ['「扌」表示和手的动作有关', '「是」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「提」？',
            options: [{ e: '🛍️', l: '提东西' }, { e: '😴', l: '睡觉' }, { e: '🎈', l: '气球' }],
            answer: 0
          },
          q4: { prompt: '___ 水', options: ['提', '题', '蹄'], answer: 0 }
        }
      ]
    },

    {
      id: 'mu',
      name: '木之族',
      radical: '木',
      shapePart: '木',
      intro: '「木」就是树。这一家的字，意思都和树木有关。',
      chars: [
        {
          c: '树', py: 'shù', emoji: '🌳',
          scene: '院子里有一棵大树。',
          parts: ['木', '对'],
          notes: ['「木」表示和树木有关', '「对」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「树」？',
            options: [{ e: '🌳', l: '大树' }, { e: '🌵', l: '仙人掌' }, { e: '🌾', l: '麦子' }],
            answer: 0
          },
          q4: { prompt: '大 ___', options: ['树', '书', '输'], answer: 0 }
        },
        {
          c: '林', py: 'lín', emoji: '🌲',
          scene: '树林里小鸟在唱歌。',
          parts: ['木', '木'],
          notes: ['「木」表示和树木有关', '两个「木」并排站着，就是一片树林'],
          q3: {
            prompt: '哪一张图是「林」？',
            options: [{ e: '🌲', l: '树林' }, { e: '🏜️', l: '沙漠' }, { e: '🌊', l: '大海' }],
            answer: 0
          },
          q4: { prompt: '树 ___', options: ['林', '邻', '临'], answer: 0 }
        },
        {
          c: '桥', py: 'qiáo', emoji: '🌉',
          scene: '小河上有一座石桥。',
          parts: ['木', '乔'],
          notes: ['「木」表示和树木有关——古时候的桥是木头搭的', '「乔」提示读音'],
          q3: {
            prompt: '哪一张图是「桥」？',
            options: [{ e: '🌉', l: '桥' }, { e: '🚗', l: '汽车' }, { e: '✈️', l: '飞机' }],
            answer: 0
          },
          q4: { prompt: '石 ___', options: ['桥', '巧', '敲'], answer: 0 }
        },
        {
          c: '桃', py: 'táo', emoji: '🍑',
          scene: '桃树上开满了粉色的花。',
          parts: ['木', '兆'],
          notes: ['「木」表示和树木有关', '「兆」提示读音'],
          q3: {
            prompt: '哪一张图是「桃」？',
            options: [{ e: '🍑', l: '桃子' }, { e: '🍌', l: '香蕉' }, { e: '🍇', l: '葡萄' }],
            answer: 0
          },
          q4: { prompt: '___ 花', options: ['桃', '逃', '淘'], answer: 0 }
        },
        {
          c: '松', py: 'sōng', emoji: '🎄',
          scene: '山坡上有一棵松树。',
          parts: ['木', '公'],
          notes: ['「木」表示和树木有关', '「公」提示读音'],
          q3: {
            prompt: '哪一张图是「松」？',
            options: [{ e: '🎄', l: '松树' }, { e: '🌻', l: '向日葵' }, { e: '🍂', l: '落叶' }],
            answer: 0
          },
          q4: { prompt: '___ 树', options: ['松', '送', '诵'], answer: 0 }
        },
        {
          c: '果', py: 'guǒ', emoji: '🍎',
          scene: '树上结满了红红的果子。',
          parts: ['木', '田'],
          notes: ['「木」表示和树木有关', '上面像「田」，果子结在树上'],
          q3: {
            prompt: '哪一张图是「果」？',
            options: [{ e: '🍎', l: '果子' }, { e: '🥕', l: '萝卜' }, { e: '🍞', l: '面包' }],
            answer: 0
          },
          q4: { prompt: '水 ___', options: ['果', '裹', '锅'], answer: 0 }
        }
      ]
    },

    {
      id: 'cao',
      name: '草之族',
      radical: '艹',
      shapePart: '艹',
      intro: '「艹」是草字头。这一家的字，意思都和花草有关。',
      chars: [
        {
          c: '花', py: 'huā', emoji: '🌸',
          scene: '花坛里开满了花。',
          parts: ['艹', '化'],
          notes: ['「艹」表示和花草有关', '「化」提示读音'],
          q3: {
            prompt: '哪一张图是「花」？',
            options: [{ e: '🌸', l: '花' }, { e: '🍎', l: '苹果' }, { e: '🐟', l: '鱼' }],
            answer: 0
          },
          q4: { prompt: '红 ___', options: ['花', '华', '划'], answer: 0 }
        },
        {
          c: '草', py: 'cǎo', emoji: '☘️',
          scene: '草地上开着小花。',
          parts: ['艹', '早'],
          notes: ['「艹」表示和花草有关', '「早」提示读音'],
          q3: {
            prompt: '哪一张图是「草」？',
            options: [{ e: '☘️', l: '小草' }, { e: '🌵', l: '仙人掌' }, { e: '🍁', l: '落叶' }],
            answer: 0
          },
          q4: { prompt: '___ 地', options: ['草', '早', '曹'], answer: 0 }
        },
        {
          c: '菜', py: 'cài', emoji: '🥬',
          scene: '妈妈买了新鲜的青菜。',
          parts: ['艹', '采'],
          notes: ['「艹」表示和花草有关', '「采」提示读音'],
          q3: {
            prompt: '哪一张图是「菜」？',
            options: [{ e: '🥬', l: '青菜' }, { e: '🍚', l: '米饭' }, { e: '🍖', l: '肉' }],
            answer: 0
          },
          q4: { prompt: '青 ___', options: ['菜', '才', '材'], answer: 0 }
        },
        {
          c: '苗', py: 'miáo', emoji: '🌱',
          scene: '田里的小苗长高了。',
          parts: ['艹', '田'],
          notes: ['「艹」表示和花草有关', '「田」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「苗」？',
            options: [{ e: '🌱', l: '小苗' }, { e: '🐛', l: '虫子' }, { e: '🪨', l: '石头' }],
            answer: 0
          },
          q4: { prompt: '树 ___', options: ['苗', '描', '庙'], answer: 0 }
        },
        {
          c: '苹', py: 'píng', emoji: '🍏',
          scene: '苹果又大又红。',
          parts: ['艹', '平'],
          notes: ['「艹」表示和花草有关', '「平」提示读音'],
          q3: {
            prompt: '哪一张图是「苹」？',
            options: [{ e: '🍏', l: '苹果' }, { e: '🍌', l: '香蕉' }, { e: '🍇', l: '葡萄' }],
            answer: 0
          },
          q4: { prompt: '___ 果', options: ['苹', '平', '评'], answer: 0 }
        },
        {
          c: '药', py: 'yào', emoji: '💊',
          scene: '生病了要按时吃药。',
          parts: ['艹', '约'],
          notes: ['「艹」表示和花草有关', '「约」帮它记住字形'],
          q3: {
            prompt: '哪一张图是「药」？',
            options: [{ e: '💊', l: '药' }, { e: '🍬', l: '糖' }, { e: '🥛', l: '牛奶' }],
            answer: 0
          },
          q4: { prompt: '吃 ___', options: ['药', '要', '耀'], answer: 0 }
        }
      ]
    }
  ]
};
