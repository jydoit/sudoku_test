class_name LocalizationController
extends RefCounted

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES := ["en", "zh", "ar", "fr", "la"]
const RTL_LOCALES := ["ar"]

const LANGUAGE_NAMES := {
	"en": "English",
	"zh": "中文",
	"ar": "العربية",
	"fr": "Français",
	"la": "Latina"
}

# Source strings stay in Chinese so existing Godot controls can use automatic
# translation. Columns: source, English, Arabic, French, Latin.
const MESSAGE_ROWS := [
	["设置", "Settings", "الإعدادات", "Paramètres", "Configurationes"],
	["语言设置", "Language settings", "إعدادات اللغة", "Paramètres de langue", "Lingua"],
	["游戏语言", "Game language", "لغة اللعبة", "Langue du jeu", "Lingua ludi"],
	["选择界面和游戏提示使用的语言。", "Choose the language used by the interface and game guidance.", "اختر لغة الواجهة وإرشادات اللعبة.", "Choisissez la langue de l’interface et des conseils.", "Linguam interfacei et consiliorum elige."],
	["取消", "Cancel", "إلغاء", "Annuler", "Renuntia"],
	["应用", "Apply", "تطبيق", "Appliquer", "Adhibe"],
	["返回首页", "Back to home", "العودة للرئيسية", "Retour à l’accueil", "Ad domum"],
	["跳过", "Skip", "تخطّي", "Passer", "Praeteri"],
	["跳过新手教程", "Skip tutorial", "تخطّي البرنامج التعليمي", "Passer le tutoriel", "Praecepta praeteri"],
	["查看消除规则", "View rules", "عرض القواعد", "Voir les règles", "Regulas vide"],
	["选择关卡", "Select level", "اختيار المرحلة", "Choisir un niveau", "Gradum elige"],
	["选关", "Levels", "المراحل", "Niveaux", "Gradus"],
	["本关生命", "Level hearts", "قلوب المرحلة", "Vies du niveau", "Corda gradus"],
	["开始关卡", "Start level", "ابدأ المرحلة", "Commencer", "Gradum incipe"],
	["新人流程", "Tutorial", "البرنامج التعليمي", "Tutoriel", "Praecepta"],
	["开始第 %d 关", "Start level %d", "ابدأ المرحلة %d", "Commencer le niveau %d", "Gradum %d incipe"],
	["继续新手教程", "Continue tutorial", "متابعة البرنامج التعليمي", "Continuer le tutoriel", "Praecepta perge"],
	["开始新手教程", "Start tutorial", "ابدأ البرنامج التعليمي", "Commencer le tutoriel", "Praecepta incipe"],
	["新手教程", "Tutorial", "البرنامج التعليمي", "Tutoriel", "Praecepta"],
	["关卡 %d", "Level %d", "المرحلة %d", "Niveau %d", "Gradus %d"],
	["关卡 %d · 难度挑战", "Level %d · Challenge", "المرحلة %d · تحدٍّ", "Niveau %d · Défi", "Gradus %d · Certamen"],
	["拼块挑战 · 第 %d 局", "Block challenge · Round %d", "تحدي القطع · الجولة %d", "Défi blocs · Manche %d", "Certamen tessellarum · Ludus %d"],
	["拼块挑战 · 第 %d 局完成", "Block challenge · Round %d complete", "اكتملت الجولة %d من تحدي القطع", "Défi blocs · Manche %d terminée", "Certamen tessellarum · Ludus %d perfectus"],
	["拼块挑战 · 第 %d 局未完成", "Block challenge · Round %d incomplete", "لم تكتمل الجولة %d من تحدي القطع", "Défi blocs · Manche %d inachevée", "Certamen tessellarum · Ludus %d non perfectus"],
	["难度挑战： ", "Challenge: ", "تحدٍّ: ", "Défi : ", "Certamen: "],
	["清除 · 免费", "Clear · Free", "مسح · مجاني", "Effacer · Gratuit", "Dele · Gratis"],
	["清除", "Clear", "مسح", "Effacer", "Dele"],
	["皇冠直找", "Find crown", "اعثر على تاج", "Trouver une couronne", "Coronam reperi"],
	["直找 ×%d", "Find ×%d", "عثور ×%d", "Trouver ×%d", "Reperi ×%d"],
	["直找 -%d", "Find -%d", "عثور -%d", "Trouver -%d", "Reperi -%d"],
	["提示", "Hint", "تلميح", "Indice", "Indicium"],
	["提示 ×%d", "Hint ×%d", "تلميح ×%d", "Indice ×%d", "Indicium ×%d"],
	["提示 -%d", "Hint -%d", "تلميح -%d", "Indice -%d", "Indicium -%d"],
	["消除规则", "Rules", "القواعد", "Règles", "Regulae"],
	["知道了", "Got it", "حسنًا", "Compris", "Intellexi"],
	["记住三个规则，把不可能的位置标记为 X。", "Remember three rules and mark impossible cells with X.", "تذكّر ثلاث قواعد وضع X على الخانات المستحيلة.", "Retenez trois règles et marquez les cases impossibles d’un X.", "Tres regulas memento et locos impossibiles X nota."],
	["皇冠周围都是 X", "X around every crown", "ضع X حول كل تاج", "Des X autour de chaque couronne", "X circa omnem coronam"],
	["皇冠的八个邻近方格不能再出现皇冠。", "The eight neighboring cells cannot contain another crown.", "لا يمكن أن تحتوي الخانات الثماني المجاورة على تاج آخر.", "Les huit cases voisines ne peuvent pas contenir une autre couronne.", "Octo cellae vicinae aliam coronam habere non possunt."],
	["每行、每列一个皇冠", "One crown per row and column", "تاج واحد في كل صف وعمود", "Une couronne par ligne et colonne", "Una corona in quoque ordine et columna"],
	["找到皇冠后，同一行和同一列的其它格都标记 X。", "After finding a crown, mark the other cells in its row and column with X.", "بعد العثور على تاج، ضع X في بقية صفه وعموده.", "Après une couronne, marquez d’un X les autres cases de sa ligne et colonne.", "Corona inventa, ceteras cellas eius ordinis et columnae X nota."],
	["每种颜色一个皇冠", "One crown per color", "تاج واحد لكل لون", "Une couronne par couleur", "Una corona cuique colori"],
	["一个颜色区域只能有一个皇冠，其余同色格标记 X。", "Each color region has one crown; mark the other cells of that color with X.", "لكل منطقة لون تاج واحد؛ ضع X على بقية خانات اللون.", "Chaque zone de couleur a une couronne ; marquez les autres cases d’un X.", "Una corona est in regione coloris; ceteras cellas eius coloris X nota."],
	["关卡选择", "Select level", "اختيار المرحلة", "Choix du niveau", "Gradum elige"],
	["进入关卡", "Enter level", "دخول المرحلة", "Entrer dans le niveau", "Gradum intra"],
	["继续新手教程？", "Continue tutorial?", "متابعة البرنامج التعليمي؟", "Continuer le tutoriel ?", "Praecepta pergis?"],
	["检测到你还没有完成新手教程。", "Your tutorial is not finished yet.", "لم تُكمل البرنامج التعليمي بعد.", "Votre tutoriel n’est pas terminé.", "Praecepta nondum perfecisti."],
	["重新开始", "Restart", "إعادة البدء", "Recommencer", "Reincipe"],
	["继续教程", "Continue", "متابعة", "Continuer", "Perge"],
	["跳过新手教程？", "Skip the tutorial?", "تخطّي البرنامج التعليمي؟", "Passer le tutoriel ?", "Praecepta praeteris?"],
	["跳过后会直接进入第 1 关，之后不再自动显示新手教程。", "You will enter level 1 and the tutorial will no longer open automatically.", "ستدخل المرحلة 1 ولن يظهر البرنامج التعليمي تلقائيًا بعد ذلك.", "Vous passerez au niveau 1 et le tutoriel ne s’ouvrira plus automatiquement.", "Gradum I intrabis, nec praecepta postea sponte apparebunt."],
	["确认跳过", "Skip", "تأكيد التخطّي", "Confirmer", "Confirma"],
	["金币不足", "Not enough coins", "عملات غير كافية", "Pas assez de pièces", "Nummi non sufficiunt"],
	["稍后再说", "Later", "لاحقًا", "Plus tard", "Postea"],
	["购买金币", "Buy coins", "شراء عملات", "Acheter des pièces", "Nummos eme"],
	["观看广告 +%d", "Watch ad +%d", "شاهد إعلانًا +%d", "Voir une pub +%d", "Nuntium vide +%d"],
	["逻辑提示", "logic hint", "تلميح منطقي", "indice logique", "indicium logicum"],
	["皇冠位置提醒", "crown finder", "العثور على تاج", "recherche de couronne", "inventio coronae"],
	["保留棋盘复活", "board-preserving revive", "إحياء مع حفظ اللوحة", "résurrection avec plateau conservé", "revivificatio tabula servata"],
	["%s需要 %d 金币。\n当前持有 %d，还差 %d。\n\n可购买金币，或主动观看一次激励广告补足本次需求。", "%s costs %d coins.\nYou have %d and need %d more.\n\nBuy coins or watch a rewarded ad to cover the shortage.", "%s يتطلب %d عملة.\nلديك %d وتحتاج %d إضافية.\n\nاشترِ عملات أو شاهد إعلانًا بمكافأة.", "%s coûte %d pièces.\nVous en avez %d et il en manque %d.\n\nAchetez des pièces ou regardez une publicité récompensée.", "%s %d nummos requirit.\n%d habes et %d desunt.\n\nNummos eme aut nuntium praemiatum vide."],
	["本关需要找到 %d 个皇冠", "Find %d crowns in this level", "اعثر على %d تيجان في هذه المرحلة", "Trouvez %d couronnes dans ce niveau", "%d coronas in hoc gradu reperi"],
	["开局提供 %d 个提示皇冠", "%d crowns are provided at the start", "يتم توفير %d تيجان في البداية", "%d couronnes sont offertes au départ", "%d coronae initio dantur"],
	["国王提示：开局已展示一个皇冠，请围绕它继续推理。", "King hint: one crown is already shown. Continue reasoning from it.", "تلميح الملك: يظهر تاج واحد في البداية. واصل الاستنتاج منه.", "Indice du roi : une couronne est déjà visible. Poursuivez le raisonnement.", "Indicium regis: una corona iam ostensa est; inde ratiocinare."],
	["放置全部皇冠，满足行、列、颜色区域和相邻规则。", "Find all crowns while satisfying row, column, color-region, and adjacency rules.", "اعثر على كل التيجان مع الالتزام بقواعد الصف والعمود واللون والتجاور.", "Trouvez toutes les couronnes en respectant lignes, colonnes, couleurs et voisinage.", "Omnes coronas reperi, regulis ordinum, columnarum, colorum et vicinitatis servatis."],
	["已放置皇冠。继续用行、列、颜色区域和相邻规则检查其它位置。", "Crown found. Use row, column, color-region, and adjacency rules to check other cells.", "تم العثور على التاج. استخدم قواعد الصف والعمود واللون والتجاور.", "Couronne trouvée. Utilisez les règles de ligne, colonne, couleur et voisinage.", "Corona inventa est; regulis ordinis, columnae, coloris et vicinitatis utere."],
	["这个位置不是皇冠，已标记为 X。", "No crown here. The cell is marked X.", "لا يوجد تاج هنا. تم وضع X.", "Pas de couronne ici. La case est marquée X.", "Corona hic non est; cella X notata est."],
	["皇冠位置错误，红心 -1", "Wrong crown position, heart -1", "موضع تاج خاطئ، قلب -1", "Mauvaise position, cœur -1", "Locus coronae falsus, cor -1"],
	["红心已用完，本关挑战失败。", "No hearts left. Level failed.", "نفدت القلوب. فشلت المرحلة.", "Plus de vies. Niveau échoué.", "Corda defecerunt; gradus victus est."],
	["已清除普通标记和错误标记，提示皇冠已保留", "Regular and wrong marks cleared; hint crowns were kept.", "تم مسح العلامات العادية والخاطئة مع إبقاء تيجان التلميح.", "Marques normales et erronées effacées ; couronnes d’indice conservées.", "Notae communes et falsae deletae sunt; coronae indicatae servantur."],
	["当前没有明显可提示的位置", "No clear hint is available now.", "لا يوجد تلميح واضح الآن.", "Aucun indice clair pour le moment.", "Nullum indicium clarum nunc est."],
	["已给出当前最优先的一步判断", "The best next step is highlighted.", "تم إبراز أفضل خطوة تالية.", "La meilleure prochaine étape est indiquée.", "Optimus proximus gradus monstratus est."],
	["当前已经没有可直接找到的皇冠", "No crown can be found directly now.", "لا يوجد تاج يمكن العثور عليه مباشرة الآن.", "Aucune couronne ne peut être trouvée directement.", "Nulla corona nunc directe reperiri potest."],
	["已直接找到一个皇冠", "One crown was found directly.", "تم العثور على تاج مباشرة.", "Une couronne a été trouvée directement.", "Una corona directe inventa est."],
	["有冲突：红色格子违反了行、列、区域或相邻规则。", "Conflict: red cells break a row, column, region, or adjacency rule.", "تعارض: الخانات الحمراء تخالف قاعدة صف أو عمود أو منطقة أو تجاور.", "Conflit : les cases rouges enfreignent une règle de ligne, colonne, zone ou voisinage.", "Conflictus: cellae rubrae regulam ordinis, columnae, regionis aut vicinitatis violant."],
	["点一下提示，看看下一步该观察哪里。", "Tap Hint to see what to examine next.", "اضغط على التلميح لمعرفة الخطوة التالية.", "Touchez Indice pour voir quoi examiner ensuite.", "Indicium tange ut proximum locum videas."],
	["点击皇冠直找，直接找到一个皇冠。教程中不会消耗使用次数。", "Tap Find crown to reveal one directly. Tutorial use is free.", "اضغط العثور على تاج لكشف تاج مباشرة. الاستخدام في التعليم مجاني.", "Touchez Trouver une couronne pour en révéler une. L’usage du tutoriel est gratuit.", "Coronam reperi tange; usus in praeceptis gratis est."],
	["皇冠不能和皇冠挨着。滑过它周围的格子，把这些位置标记为 X。", "Crowns cannot touch. Swipe around it to mark those cells X.", "لا يمكن أن تتلامس التيجان. اسحب حوله لوضع X.", "Les couronnes ne se touchent pas. Balayez autour pour marquer des X.", "Coronae se tangere non possunt; circa eam trahe et X nota."],
	["每行、每列都只能有一个皇冠。这个皇冠所在的行和列，其他格都可以标记 X。", "Each row and column has one crown. Mark the other cells in this crown’s row and column X.", "لكل صف وعمود تاج واحد. ضع X في بقية صف وعمود هذا التاج.", "Chaque ligne et colonne a une couronne. Marquez d’un X les autres cases de sa ligne et colonne.", "Unum corona in quoque ordine et columna est; ceteras cellas X nota."],
	["每个颜色区域都要找到一个皇冠。现在这个区域只剩一个可选格，双击找到它。", "Each color region needs one crown. Only one cell remains here; double-tap it.", "تحتاج كل منطقة لون إلى تاج. بقيت خانة واحدة؛ انقر عليها مرتين.", "Chaque zone de couleur a une couronne. Il ne reste qu’une case ; touchez-la deux fois.", "Una corona cuique regioni coloris; una cella restat, bis tange."],
	["每行、每列都要找到一个皇冠。现在只剩这个位置符合规则，双击找到最后一个皇冠。", "Each row and column needs one crown. Only this cell fits; double-tap the final crown.", "يحتاج كل صف وعمود إلى تاج. هذه الخانة الوحيدة المناسبة؛ انقر مرتين.", "Chaque ligne et colonne a une couronne. Seule cette case convient ; touchez-la deux fois.", "Una corona cuique ordini et columnae; haec sola cella convenit, bis tange."],
	["皇冠直找已直接找到并锁定皇冠，周围位置已经排除。继续排除同行同列。", "Find crown revealed and locked a crown. Its neighbors are already excluded; continue along its row and column.", "كشف العثور على تاج تاجًا وثبّته. الجوار مستبعد بالفعل؛ تابع الصف والعمود.", "Trouver une couronne l’a révélée et verrouillée. Les voisines sont exclues ; continuez sa ligne et colonne.", "Corona inventa et fixa est; vicina iam exclusa sunt, ordinem et columnam perge."],
	["已经了解全部规则，开始真正的挑战吧！", "You know all the rules. Start the real challenge!", "لقد عرفت كل القواعد. ابدأ التحدي الحقيقي!", "Vous connaissez toutes les règles. Place au vrai défi !", "Omnes regulas nosti; verum certamen incipe!"],
	["已经了解全部规则", "All rules learned", "تم تعلم كل القواعد", "Toutes les règles sont apprises", "Omnes regulae cognitae"],
	["开始真正的挑战吧！", "Start the real challenge!", "ابدأ التحدي الحقيقي!", "Commencez le vrai défi !", "Verum certamen incipe!"],
	["新手教程完成", "Tutorial complete", "اكتمل البرنامج التعليمي", "Tutoriel terminé", "Praecepta perfecta"],
	["进入第 1 关，开始真正的挑战", "Enter level 1 and start the real challenge.", "ادخل المرحلة 1 وابدأ التحدي الحقيقي.", "Entrez dans le niveau 1 et commencez le vrai défi.", "Gradum I intra et verum certamen incipe."],
	["开始挑战", "Start challenge", "ابدأ التحدي", "Commencer le défi", "Certamen incipe"],
	["太棒了！", "Great!", "رائع!", "Bravo !", "Optime!"],
	["第 %d 关 已完成", "Level %d complete", "اكتملت المرحلة %d", "Niveau %d terminé", "Gradus %d perfectus"],
	["下一关", "Next level", "المرحلة التالية", "Niveau suivant", "Proximus gradus"],
	["下一局", "Next round", "الجولة التالية", "Manche suivante", "Proximus ludus"],
	["主菜单", "Main menu", "القائمة الرئيسية", "Menu principal", "Tabula princeps"],
	["挑战失败", "Challenge failed", "فشل التحدي", "Défi échoué", "Certamen victum"],
	["第 %d 关 未完成", "Level %d incomplete", "المرحلة %d غير مكتملة", "Niveau %d non terminé", "Gradus %d non perfectus"],
	["红心已用完", "No hearts left", "نفدت القلوب", "Plus de vies", "Corda defecerunt"],
	["复活会保留当前棋盘，并恢复 1 颗红心", "Revive keeps the board and restores one heart.", "الإحياء يحفظ اللوحة ويعيد قلبًا واحدًا.", "La résurrection conserve le plateau et rend une vie.", "Revivificatio tabulam servat et unum cor reddit."],
	["金币复活  -%d", "Revive -%d", "إحياء -%d", "Ressusciter -%d", "Revivisce -%d"],
	["重新挑战", "Retry", "إعادة المحاولة", "Réessayer", "Iterum tenta"],
	["关卡 %d · %s", "Level %d · %s", "المرحلة %d · %s", "Niveau %d · %s", "Gradus %d · %s"],
	["simple", "Easy", "سهل", "Facile", "Facilis"],
	["normal", "Normal", "عادي", "Normal", "Communis"],
	["medium", "Medium", "متوسط", "Moyen", "Medius"],
	["hard", "Hard", "صعب", "Difficile", "Difficilis"],
	["expert", "Expert", "خبير", "Expert", "Peritus"],
	["已进入关卡 %d", "Entered level %d", "تم دخول المرحلة %d", "Niveau %d chargé", "Gradus %d initus est"],
	["完成新手教程后即可选择关卡", "Finish the tutorial to select levels.", "أكمل البرنامج التعليمي لاختيار المراحل.", "Terminez le tutoriel pour choisir les niveaux.", "Praecepta perfice ut gradus eligas."],
	["已进入新人流程", "Tutorial started", "بدأ البرنامج التعليمي", "Tutoriel démarré", "Praecepta incepta"],
	["已跳过教程，进入第 1 关", "Tutorial skipped. Entering level 1.", "تم تخطّي التعليم. دخول المرحلة 1.", "Tutoriel passé. Entrée au niveau 1.", "Praecepta praeterita; gradus I initur."],
	["新手教程完成，进入第 1 关", "Tutorial complete. Entering level 1.", "اكتمل التعليم. دخول المرحلة 1.", "Tutoriel terminé. Entrée au niveau 1.", "Praecepta perfecta; gradus I initur."],
	["先拼好颜色区域", "Complete the color regions first", "أكمل مناطق الألوان أولًا", "Complétez d’abord les zones de couleur", "Regiones colorum primum perfice"],
	["玩法帮助", "How to play", "طريقة اللعب", "Comment jouer", "Modus ludendi"],
	["拼块玩法", "Block assembly", "تركيب القطع", "Assemblage des blocs", "Compositio tessellarum"],
	["先补完整个颜色区域，再开始找皇冠。", "Complete the color regions, then find the crowns.", "أكمل مناطق الألوان ثم ابحث عن التيجان.", "Complétez les zones de couleur, puis trouvez les couronnes.", "Regiones colorum perfice, deinde coronas reperi."],
	["向上拖出彩色方块", "Drag a colored block upward", "اسحب قطعة ملونة إلى الأعلى", "Faites glisser un bloc coloré vers le haut", "Tessellam coloratam sursum trahe"],
	["完整对齐空白凹槽", "Align the whole block with the empty well", "حاذِ القطعة بالكامل مع التجويف", "Alignez tout le bloc avec le creux", "Totam tessellam cum cavitate compone"],
	["可以随时拿回重放", "Return and replay blocks anytime", "يمكنك إعادة القطع في أي وقت", "Reprenez et replacez les blocs à tout moment", "Tessellas quandocumque recipe"],
	["拼完自动进入找皇冠", "Finish to start finding crowns", "أكمل للبدء في العثور على التيجان", "Terminez pour chercher les couronnes", "Perfice ut coronas reperias"],
	["重播演示", "Replay demo", "إعادة العرض", "Revoir la démo", "Demonstrationem repete"],
	["锁定区域不需要移动", "Locked regions stay in place", "تبقى المناطق المثبتة في مكانها", "Les zones verrouillées restent en place", "Regiones fixae manent"],
	["把彩色方块拖进空白凹槽", "Drag colored blocks into the empty well", "اسحب القطع الملونة إلى التجويف الفارغ", "Glissez les blocs colorés dans le creux", "Tessellas coloratas in cavitatem trahe"],
	["左右滑动托盘查看更多", "Swipe the tray to see more", "مرّر الصينية لرؤية المزيد", "Faites défiler le plateau", "Repositorium move ut plura videas"],
	["已放方块可以拖回托盘", "Placed blocks can return to the tray", "يمكن إعادة القطع الموضوعة إلى الصينية", "Les blocs posés peuvent revenir au plateau", "Tessellae positae ad repositorium redire possunt"],
	["进入拼块阶段后可以重播演示", "Replay is available during block assembly.", "يمكن إعادة العرض أثناء تركيب القطع.", "La démo est disponible pendant l’assemblage.", "Demonstratio in compositione praesto est."],
	["请跟随高亮提示继续操作。", "Follow the highlighted guidance to continue.", "اتبع الإرشاد المضيء للمتابعة.", "Suivez l’indication en surbrillance pour continuer.", "Indicium illuminatum sequere."],
	["请观察棋盘中保持明亮的格子，并根据行、列、颜色区域和相邻规则继续推理。", "Observe the bright cells and continue using row, column, color-region, and adjacency rules.", "راقب الخانات المضيئة وتابع باستخدام قواعد الصف والعمود واللون والتجاور.", "Observez les cases claires et poursuivez avec les règles de ligne, colonne, couleur et voisinage.", "Cellas claras observa et regulis ordinis, columnae, coloris et vicinitatis perge."]
]

var current_locale := DEFAULT_LOCALE
var _translations: Array[Translation] = []


func initialize(saved_locale: String = "") -> void:
	_install_translations()
	var requested := saved_locale if not saved_locale.is_empty() else TranslationServer.get_locale()
	set_locale(requested, false)


func set_locale(requested_locale: String, emit_change: bool = true) -> void:
	current_locale = locale_for_system(requested_locale)
	TranslationServer.set_locale(current_locale)
	if emit_change:
		locale_changed.emit(current_locale)


func text(source: String, values: Array = []) -> String:
	var translated := str(TranslationServer.translate(source))
	if values.is_empty():
		return translated
	return translated % values


func runtime_text(source: String, generic_source: String = "请跟随高亮提示继续操作。") -> String:
	var translated := str(TranslationServer.translate(source))
	if current_locale != "zh" and translated == source and _contains_cjk(source):
		return text(generic_source)
	return translated


func is_rtl() -> bool:
	return RTL_LOCALES.has(current_locale)


func language_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for locale in SUPPORTED_LOCALES:
		result.append({"code": locale, "name": str(LANGUAGE_NAMES[locale])})
	return result


func locale_index(locale: String) -> int:
	var normalized := locale_for_system(locale)
	return maxi(0, SUPPORTED_LOCALES.find(normalized))


static func locale_for_system(system_locale: String) -> String:
	var normalized := system_locale.strip_edges().to_lower().replace("-", "_")
	var language := normalized.get_slice("_", 0)
	if language == "zh":
		return "zh"
	if language == "ar":
		return "ar"
	if language == "fr":
		return "fr"
	if language == "la":
		return "la"
	return DEFAULT_LOCALE


func _install_translations() -> void:
	if not _translations.is_empty():
		return
	var locale_columns := {"zh": 0, "en": 1, "ar": 2, "fr": 3, "la": 4}
	for locale in locale_columns:
		var translation := Translation.new()
		translation.locale = locale
		for row in MESSAGE_ROWS:
			translation.add_message(str(row[0]), str(row[int(locale_columns[locale])]))
		TranslationServer.add_translation(translation)
		_translations.append(translation)


func _contains_cjk(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint >= 0x3400 and codepoint <= 0x9FFF:
			return true
	return false
