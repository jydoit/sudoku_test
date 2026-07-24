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
	["新人引导", "Tutorial", "البرنامج التعليمي", "Tutoriel", "Praecepta"],
	["开始第 %d 关", "Start level %d", "ابدأ المرحلة %d", "Commencer le niveau %d", "Gradum %d incipe"],
	["继续新手教程", "Continue tutorial", "متابعة البرنامج التعليمي", "Continuer le tutoriel", "Praecepta perge"],
	["开始新手教程", "Start tutorial", "ابدأ البرنامج التعليمي", "Commencer le tutoriel", "Praecepta incipe"],
	["新手教程", "Tutorial", "البرنامج التعليمي", "Tutoriel", "Praecepta"],
	["关卡 %d", "Level %d", "المرحلة %d", "Niveau %d", "Gradus %d"],
	["关卡 %d · 难度挑战", "Level %d · Challenge", "المرحلة %d · تحدٍّ", "Niveau %d · Défi", "Gradus %d · Certamen"],
	["难度挑战： ", "Challenge: ", "تحدٍّ: ", "Défi : ", "Certamen: "],
	["小狮子", "Lion", "أسد صغير", "Lionceau", "Leo parvus"],
	["小狮子 ×%d", "Lion ×%d", "أسد ×%d", "Lionceau ×%d", "Leo ×%d"],
	["小狮子 -%d", "Lion -%d", "أسد -%d", "Lionceau -%d", "Leo -%d"],
	["提示", "Hint", "تلميح", "Indice", "Indicium"],
	["提示 ×%d", "Hint ×%d", "تلميح ×%d", "Indice ×%d", "Indicium ×%d"],
	["提示 -%d", "Hint -%d", "تلميح -%d", "Indice -%d", "Indicium -%d"],
	["消除规则", "Rules", "القواعد", "Règles", "Regulae"],
	["知道了", "Got it", "حسنًا", "Compris", "Intellexi"],
	["记住三个规则，把不可能的位置标记为 X。", "Remember three rules and mark impossible cells with X.", "تذكّر ثلاث قواعد وضع X على الخانات المستحيلة.", "Retenez trois règles et marquez les cases impossibles d’un X.", "Tres regulas memento et locos impossibiles X nota."],
	["小狮子周围都是 X", "X around every lion", "ضع X حول كل أسد", "Des X autour de chaque lionceau", "X circa omnem leonem"],
	["小狮子的八个邻近方格不能再出现小狮子。", "The eight neighboring cells cannot contain another lion.", "لا يمكن أن تحتوي الخانات الثماني المجاورة على أسد آخر.", "Les huit cases voisines ne peuvent pas contenir une autre lionceau.", "Octo cellae vicinae aliam leonem habere non possunt."],
	["每行、每列一个小狮子", "One lion per row and column", "أسد واحد في كل صف وعمود", "Un lionceau par ligne et colonne", "Una leonem in quoque ordine et columna"],
	["找到小狮子后，同一行和同一列的其它格都标记 X。", "After finding a lion, mark the other cells in its row and column with X.", "بعد العثور على أسد، ضع X في بقية صفه وعموده.", "Après un lionceau, marquez d’un X les autres cases de sa ligne et colonne.", "Leo inventa, ceteras cellas eius ordinis et columnae X nota."],
	["每种颜色一个小狮子", "One lion per color", "أسد واحد لكل لون", "Un lionceau par couleur", "Una leonem cuique colori"],
	["一个颜色区域只能有一个小狮子，其余同色格标记 X。", "Each color region has one lion; mark the other cells of that color with X.", "لكل منطقة لون أسد واحد؛ ضع X على بقية خانات اللون.", "Chaque zone de couleur a un lionceau ; marquez les autres cases d’un X.", "Una leonem est in regione coloris; ceteras cellas eius coloris X nota."],
	["关卡选择", "Select level", "اختيار المرحلة", "Choix du niveau", "Gradum elige"],
	["上一页", "Previous", "السابق", "Précédent", "Prior"],
	["下一页", "Next", "التالي", "Suivant", "Proximus"],
	["%d–%d 关", "Levels %d–%d", "المراحل %d–%d", "Niveaux %d–%d", "Gradus %d–%d"],
	["已选：关卡 %d", "Selected: level %d", "المحدد: المرحلة %d", "Sélection : niveau %d", "Electus: gradus %d"],
	["进入关卡 %d", "Enter level %d", "دخول المرحلة %d", "Entrer au niveau %d", "Gradum %d inire"],
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
	["小狮子直找", "lion finder", "العثور على الأسد", "recherche de lionceau", "inventio leonis"],
	["保留棋盘复活", "board-preserving revive", "إحياء مع حفظ اللوحة", "résurrection avec plateau conservé", "revivificatio tabula servata"],
	["%s需要 %d 金币。\n当前持有 %d，还差 %d。\n\n可购买金币，或主动观看一次激励广告补足本次需求。", "%s costs %d coins.\nYou have %d and need %d more.\n\nBuy coins or watch a rewarded ad to cover the shortage.", "%s يتطلب %d عملة.\nلديك %d وتحتاج %d إضافية.\n\nاشترِ عملات أو شاهد إعلانًا بمكافأة.", "%s coûte %d pièces.\nVous en avez %d et il en manque %d.\n\nAchetez des pièces ou regardez une publicité récompensée.", "%s %d nummos requirit.\n%d habes et %d desunt.\n\nNummos eme aut nuntium praemiatum vide."],
	["本关需要找到 %d 个小狮子", "Find %d lions in this level", "اعثر على %d أسود في هذه المرحلة", "Trouvez %d lionceaux dans ce niveau", "%d leones in hoc gradu reperi"],
	["开局提供 1 个提示小狮子", "1 lion is provided at the start", "يتم توفير أسد واحد في البداية", "1 lionceau est offert au départ", "Unus leo initio datur"],
	["开局提供 %d 个提示小狮子", "%d lions are provided at the start", "يتم توفير %d أسود في البداية", "%d lionceaux sont offertes au départ", "%d leones initio dantur"],
	["国王提示：开局已展示一个小狮子，请围绕它继续推理。", "King hint: one lion is already shown. Continue reasoning from it.", "تلميح الملك: يظهر أسد واحد في البداية. واصل الاستنتاج منه.", "Indice du roi : un lionceau est déjà visible. Poursuivez le raisonnement.", "Indicium regis: una leonem iam ostensa est; inde ratiocinare."],
	["放置全部小狮子，满足行、列、颜色区域和相邻规则。", "Find all lions while satisfying row, column, color-region, and adjacency rules.", "اعثر على كل الأسود مع الالتزام بقواعد الصف والعمود واللون والتجاور.", "Trouvez tous les lionceaux en respectant lignes, colonnes, couleurs et voisinage.", "Omnes leones reperi, regulis ordinum, columnarum, colorum et vicinitatis servatis."],
	["已放置小狮子。继续用行、列、颜色区域和相邻规则检查其它位置。", "Lion found. Use row, column, color-region, and adjacency rules to check other cells.", "تم العثور على الأسد. استخدم قواعد الصف والعمود واللون والتجاور.", "Lionceau trouvé. Utilisez les règles de ligne, colonne, couleur et voisinage.", "Leo inventa est; regulis ordinis, columnae, coloris et vicinitatis utere."],
	["这个位置不是小狮子，已标记为 X。", "No lion here. The cell is marked X.", "لا يوجد أسد هنا. تم وضع X.", "Pas de lionceau ici. La case est marquée X.", "Leo hic non est; cella X notata est."],
	["红心已用完，本关挑战失败。", "No hearts left. Level failed.", "نفدت القلوب. فشلت المرحلة.", "Plus de vies. Niveau échoué.", "Corda defecerunt; gradus victus est."],
	["已清除普通标记和错误标记，提示小狮子已保留", "Regular and wrong marks cleared; hint lions were kept.", "تم مسح العلامات العادية والخاطئة مع إبقاء أسود التلميح.", "Marques normales et erronées effacées ; lionceaux d’indice conservés.", "Notae communes et falsae deletae sunt; leones indicatae servantur."],
	["当前没有明显可提示的位置", "No clear hint is available now.", "لا يوجد تلميح واضح الآن.", "Aucun indice clair pour le moment.", "Nullum indicium clarum nunc est."],
	["已给出当前最优先的一步判断", "The best next step is highlighted.", "تم إبراز أفضل خطوة تالية.", "La meilleure prochaine étape est indiquée.", "Optimus proximus gradus monstratus est."],
	["当前已经没有可直接找到的小狮子", "No lion can be found directly now.", "لا يوجد أسد يمكن العثور عليه مباشرة الآن.", "Aucun lionceau ne peut être trouvée directement.", "Nulla leonem nunc directe reperiri potest."],
	["当前已经没有可直接找到的小狮子", "No lion can be found directly now.", "لا يوجد أسد يمكن العثور عليه مباشرة الآن.", "Aucun lionceau ne peut être trouvé directement.", "Nullus leo directe reperiri potest."],
	["已直接找到一个小狮子", "One lion was found directly.", "تم العثور على أسد مباشرة.", "Un lionceau a été trouvé directement.", "Unus leo directe inventus est."],
	["有冲突：红色格子违反了行、列、区域或相邻规则。", "Conflict: red cells break a row, column, region, or adjacency rule.", "تعارض: الخانات الحمراء تخالف قاعدة صف أو عمود أو منطقة أو تجاور.", "Conflit : les cases rouges enfreignent une règle de ligne, colonne, zone ou voisinage.", "Conflictus: cellae rubrae regulam ordinis, columnae, regionis aut vicinitatis violant."],
	["点一下提示，看看下一步该观察哪里。", "Tap Hint to see what to examine next.", "اضغط على التلميح لمعرفة الخطوة التالية.", "Touchez Indice pour voir quoi examiner ensuite.", "Indicium tange ut proximum locum videas."],
	["点击小狮子，直接找到一个小狮子。教程中不会消耗使用次数。", "Tap Lion to reveal one directly. Tutorial use is free.", "اضغط الأسد لكشف أسد مباشرة. الاستخدام في التعليم مجاني.", "Touchez Lionceau pour en révéler un. L’usage du tutoriel est gratuit.", "Leonem tange; usus in praeceptis gratis est."],
	["小狮子不能和小狮子挨着。滑过它周围的格子，把这些位置标记为 X。", "Lions cannot touch. Swipe around it to mark those cells X.", "لا يمكن أن تتلامس الأسود. اسحب حوله لوضع X.", "Les lionceaux ne se touchent pas. Balayez autour pour marquer des X.", "Leones se tangere non possunt; circa eam trahe et X nota."],
	["每行、每列都只能有一个小狮子。这个小狮子所在的行和列，其他格都可以标记 X。", "Each row and column has one lion. Mark the other cells in this lion’s row and column X.", "لكل صف وعمود أسد واحد. ضع X في بقية صف وعمود هذا الأسد.", "Chaque ligne et colonne a un lionceau. Marquez d’un X les autres cases de sa ligne et colonne.", "Unum leonem in quoque ordine et columna est; ceteras cellas X nota."],
	["每个颜色区域都要找到一个小狮子。现在这个区域只剩一个可选格，双击找到它。", "Each color region needs one lion. Only one cell remains here; double-tap it.", "تحتاج كل منطقة لون إلى أسد. بقيت خانة واحدة؛ انقر عليها مرتين.", "Chaque zone de couleur a un lionceau. Il ne reste qu’une case ; touchez-la deux fois.", "Una leonem cuique regioni coloris; una cella restat, bis tange."],
	["每行、每列都要找到一个小狮子。现在只剩这个位置符合规则，双击找到最后一个小狮子。", "Each row and column needs one lion. Only this cell fits; double-tap the final lion.", "يحتاج كل صف وعمود إلى أسد. هذه الخانة الوحيدة المناسبة؛ انقر مرتين.", "Chaque ligne et colonne a un lionceau. Seule cette case convient ; touchez-la deux fois.", "Una leonem cuique ordini et columnae; haec sola cella convenit, bis tange."],
	["小狮子按钮已直接找到并锁定小狮子，周围位置已经排除。继续排除同行同列。", "Lion has revealed and locked a cell. Its neighbors are already excluded; continue along its row and column.", "كشف زر الأسد خانة وثبتها. الجوار مستبعد بالفعل؛ تابع الصف والعمود.", "Lionceau a révélé et verrouillé une case. Les voisines sont exclues ; continuez sa ligne et colonne.", "Leo cellam aperuit et fixit; vicina exclusa sunt, ordinem et columnam perge."],
	["已经了解全部规则，开始真正的挑战吧！", "You know all the rules. Start the real challenge!", "لقد عرفت كل القواعد. ابدأ التحدي الحقيقي!", "Vous connaissez toutes les règles. Place au vrai défi !", "Omnes regulas nosti; verum certamen incipe!"],
	["已经了解全部规则", "All rules learned", "تم تعلم كل القواعد", "Toutes les règles sont apprises", "Omnes regulae cognitae"],
	["开始真正的挑战吧！", "Start the real challenge!", "ابدأ التحدي الحقيقي!", "Commencez le vrai défi !", "Verum certamen incipe!"],
	["新手教程完成", "Tutorial complete", "اكتمل البرنامج التعليمي", "Tutoriel terminé", "Praecepta perfecta"],
	["进入第 1 关，开始真正的挑战", "Enter level 1 and start the real challenge.", "ادخل المرحلة 1 وابدأ التحدي الحقيقي.", "Entrez dans le niveau 1 et commencez le vrai défi.", "Gradum I intra et verum certamen incipe."],
	["开始挑战", "Start challenge", "ابدأ التحدي", "Commencer le défi", "Certamen incipe"],
	["太棒了！", "Great!", "رائع!", "Bravo !", "Optime!"],
	["第 %d 关 已完成", "Level %d complete", "اكتملت المرحلة %d", "Niveau %d terminé", "Gradus %d perfectus"],
	["下一关", "Next level", "المرحلة التالية", "Niveau suivant", "Proximus gradus"],
	["主菜单", "Main menu", "القائمة الرئيسية", "Menu principal", "Tabula princeps"],
	["挑战失败", "Challenge failed", "فشل التحدي", "Défi échoué", "Certamen victum"],
	["再试一次", "Try again", "حاول مرة أخرى", "Réessayez", "Iterum tenta"],
	["第 %d 关 未完成", "Level %d incomplete", "المرحلة %d غير مكتملة", "Niveau %d non terminé", "Gradus %d non perfectus"],
	["红心已用完", "No hearts left", "نفدت القلوب", "Plus de vies", "Corda defecerunt"],
	["红心用完了", "No hearts left", "نفدت القلوب", "Plus de vies", "Corda defecerunt"],
	["重新挑战，帮小狮子找回信心", "Try again and help the lion regain confidence.", "حاول مجددًا وساعد الأسد ليستعيد ثقته.", "Réessayez et aidez le lionceau à reprendre confiance.", "Iterum tenta et leoni fiduciam redde."],
	["重新挑战", "Retry", "إعادة المحاولة", "Réessayer", "Iterum tenta"],
	["关卡 %d · %s", "Level %d · %s", "المرحلة %d · %s", "Niveau %d · %s", "Gradus %d · %s"],
	["simple", "Easy", "سهل", "Facile", "Facilis"],
	["normal", "Normal", "عادي", "Normal", "Communis"],
	["medium", "Medium", "متوسط", "Moyen", "Medius"],
	["hard", "Hard", "صعب", "Difficile", "Difficilis"],
	["expert", "Expert", "خبير", "Expert", "Peritus"],
	["已进入关卡 %d", "Entered level %d", "تم دخول المرحلة %d", "Niveau %d chargé", "Gradus %d initus est"],
	["完成新手教程后即可选择关卡", "Finish the tutorial to select levels.", "أكمل البرنامج التعليمي لاختيار المراحل.", "Terminez le tutoriel pour choisir les niveaux.", "Praecepta perfice ut gradus eligas."],
	["已进入新人引导", "Tutorial started", "بدأ البرنامج التعليمي", "Tutoriel démarré", "Praecepta incepta"],
	["已跳过教程，进入第 1 关", "Tutorial skipped. Entering level 1.", "تم تخطّي التعليم. دخول المرحلة 1.", "Tutoriel passé. Entrée au niveau 1.", "Praecepta praeterita; gradus I initur."],
	["新手教程完成，进入第 1 关", "Tutorial complete. Entering level 1.", "اكتمل التعليم. دخول المرحلة 1.", "Tutoriel terminé. Entrée au niveau 1.", "Praecepta perfecta; gradus I initur."],
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
