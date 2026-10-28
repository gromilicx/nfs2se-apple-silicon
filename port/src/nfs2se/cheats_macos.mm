#import <AppKit/AppKit.h>

#include "cheats.h"
#include <algorithm>
#include <string>
#include <vector>

namespace {
struct CheatEntry {
    std::string title;
    std::string code;
    std::string category;
    std::string detail;
    std::string action;
    std::string availability;
    bool supported = true;
};

NSString* text(const std::string& value) {
    return [NSString stringWithUTF8String:value.c_str()] ?: @"";
}

std::vector<CheatEntry> makeEntries() {
    std::vector<CheatEntry> entries;
    const auto add = [&](const char* title, const char* code, const char* category,
                         const char* detail, const char* action,
                         bool supported = true, const char* availability = "Podržano") {
        entries.push_back({title, code, category, detail, action, availability, supported});
    };
    add("FZR 2000", "fzr2000", "Automobili",
        "Otključava i odmah bira FZR 2000 za sledeću trku. Ovaj meni može ponovo da ga izabere i kada je već otključan. Pri izboru uklanja prethodnu GO zamenu vozila.", "fzr2000");
    add("Daytona", "tombstone", "Automobili",
        "Otključava i bira skriveni Daytona automobil. Ovaj meni može ponovo da ga izabere i kada je već otključan. Pri izboru uklanja prethodnu GO zamenu vozila.", "tombstone");
    add("BFS Bomber", "bomber", "Automobili",
        "Otključava i bira skriveni Bomber automobil. Ovaj meni može ponovo da ga izabere i kada je već otključan. Pri izboru uklanja prethodnu GO zamenu vozila.", "bomber");
    add("Monolithic Studios", "hollywood", "Staze i prikaz",
        "Otključava skrivenu stazu Monolithic Studios i bira je u meniju igre. Zatim možeš da podesiš ostale opcije i pokreneš trku.", "hollywood");
    add("Pioneer motor", "pioneer", "Efekti i saobraćaj",
        "Uključuje originalnu Pioneer opciju motora. Igra zatim prikazuje svoju poruku: zatvori je u samoj igri. Prihvatanje koda je provereno; njegov uticaj u vožnji nije zasebno vizuelno proveren.", "pioneer");
    add("Klizav put", "slip", "Efekti i saobraćaj",
        "Menja prianjanje podloge tako da put bude klizav. U ovoj verziji SLIP utiče na fiziku prianjanja; opis „usporeni snimak“ iz vodiča nije tačan.", "slip");
    add("Slot opcija automobila", "slot", "Automobili",
        "Otključava opciju Slot u izboru automobila. Zatim je izaberi u Player Car meniju uz Arcade ili Wild stil vožnje. Automobili u tom režimu sami prate krivine. Radnja „Ukloni efekte“ zadržava otključanu Slot opciju.", "slot");
    add("Kravlje gume", "mad", "Staze i prikaz",
        "Originalni spisak prepoznaje MAD, ali njegov poziv u ovoj verziji ne menja nijednu opciju. Efekat iz vodiča pripada 3Dfx prikazu i ovde nije dostupan.", "", false, "Nema efekta");
    add("Kiša", "rain", "Staze i prikaz",
        "Uključuje kišne delove staze na Proving Grounds, North Country i Mystic Peaks. Kiša zavisi od dela podržane staze; na ostalim stazama ovaj kod nema kišne regione.", "rain");
    add("Chase režim", "chase", "Efekti i saobraćaj",
        "Uključuje originalni Chase režim za sledeću trku. Prihvatanje koda i odgovarajuća opcija igre su provereni. Ponašanje u samoj trci nije zasebno vizuelno provereno.", "chase");
    add("Šareni auto i horizont", "kcjones", "Staze i prikaz",
        "Originalni spisak prepoznaje KCJONES, ali ova verzija nema njegov efekat. Efekat iz vodiča zahteva 3Dfx prikaz, pa automatsko uključivanje nije ponuđeno.", "", false, "Nema efekta");
    add("Gušći saobraćaj", "rushhour", "Efekti i saobraćaj",
        "Uključuje dodatni saobraćaj kada postavke trke to dozvoljavaju. Ako si izabrao GO vozilo ili predmet, saobraćaj takođe može koristiti taj model.", "rushhour");
    add("Dinosaurusi u saobraćaju", "rexhour", "Efekti i saobraćaj",
        "Bira T-Rex model za vozila igrača i protivnika i uključuje takav saobraćaj. Tačan kod ove verzije je REXHOUR. REXRAGE sa slike nije prepoznat.", "rexhour");
    add("Drvene kućice u saobraćaju", "madland", "Efekti i saobraćaj",
        "Bira drvenu kućicu za vozila igrača i protivnika, uključuje takav saobraćaj i Pioneer opciju. Opis „različite boje“ iz vodiča ne odgovara ovoj verziji.", "madland");
    add("Školski autobusi", "schoolzone", "Efekti i saobraćaj",
        "Bira školski autobus za vozila igrača i protivnika, uključuje takav saobraćaj i Pioneer opciju. Za povratak na običan automobil izaberi „Običan automobil“ ili „Ukloni efekte“.", "schoolzone");
    add("Limuzine", "vip", "Efekti i saobraćaj",
        "Bira limuzinu za vozila igrača i protivnika, uključuje takav saobraćaj i Pioneer opciju. Za povratak na običan automobil izaberi „Običan automobil“ ili „Ukloni efekte“.", "vip");
    add("Roadrage sirena", "roadrage", "Efekti i saobraćaj",
        "Uključuje originalni Roadrage režim. Vodiči ga opisuju kao izazivanje sudara protivnika sirenom. Aktiviranje opcije je provereno; taj efekat u vožnji nije zasebno vizuelno proveren.", "roadrage");

    const char* modelNames[] = {
        "Školski autobus", "Pickup", "Školski autobus", "Kamion", "Školski autobus",
        "Plavi Audi sedan", "Školski autobus", "Školski autobus", "Mercedes",
        "Zeleni Volkswagen", "Siva Mazda kabriolet", "Školski autobus", "Školski autobus",
        "Vojni Unimog", "Školski autobus", "Snežni kamion", "Tramvaj", "Limuzina",
        "Siva Mazda kabriolet", "Školski autobus", "Školski autobus", "Školski autobus",
        "Sanduk", "Ručna kolica", "Drvena kućica", "Tyrannosaurus Rex", "Zaprežna kola",
        "Štand sa suvenirima 1", "Štand sa suvenirima 2", "Kiosk", "Balvan", "Kutija",
        "Kutija piva", "Kamen"
    };
    for (unsigned number = 18; number <= 51; ++number) {
        const std::string code = "go" + std::to_string(number);
        std::string detail = "Zamenjuje vozilo igrača i protivnika modelom: ";
        detail += modelNames[number - 18];
        detail += ". Originalni meni automobila može prikazivati prethodni auto; zamena važi u sledećoj trci. Sam GO kod ne uključuje dodatni saobraćaj. Uz RUSHHOUR i saobraćaj može koristiti ovaj model.";
        if (number == 18 || number == 22 || number == 24 || number == 25 ||
            number == 29 || number == 30 || number == 32 ||
            number == 37 || number == 38 || number == 39)
            detail += " Ovaj broj koristi školski autobus, kao GO20.";
        entries.push_back({modelNames[number - 18], code, "GO vozila i predmeti", detail, code, "Podržano", true});
    }
    add("Običan automobil", "Radnja menija", "Automobili",
        "Uklanja GO i slične zamene vozila. Zatim koristi automobil koji izabereš u Player Car meniju. Ostali uključeni efekti ostaju aktivni; za njih koristi „Ukloni efekte“.", "normalcar");
    add("Noćni prikaz", "N pri učitavanju", "Staze i prikaz",
        "Automatski drži N tokom originalnog učitavanja narednih trka i tako uključuje noćni prikaz neba i osvetljenja. Primenjuje se na naredne trke dok ne izabereš „Ukloni efekte“ ili ponovo pokreneš igru.", "night");
    add("Devet pogleda kamere", "C + B + desni Shift", "Staze i prikaz",
        "Automatski drži C, B i desni Shift tokom pripreme kamere za naredne trke. Omogućava devet originalnih pogleda; menjaj ih uobičajenim tasterom kamere. U ovom kodu nema uslova da kombinaciju pritisneš šest puta. Primenjuje se do „Ukloni efekte“ ili ponovnog pokretanja igre.", "cameras");
    add("Teži automobil", "SIL SPD", "Posebni postupci",
        "Izvorni kod proverava tačno ime SIL SPD, velikim slovima i sa razmakom. Pri poklapanju primenjuje četvorostruku masu automobila. Vodič predlaže unos tog imena posle rekorda staze; unos, formatiranje i čuvanje imena nisu potvrđeni testom u igri. Ovo se ne aktivira iz glavnog menija.", "", false, "Postupak");
    add("Turbo na taster H", "H u trci", "Posebni postupci",
        "Priloženi vodič tvrdi da držanje H tokom trke daje turbo. Takav tajni okidač još nije potvrđen u ovoj verziji, pa meni ne nudi automatsko uključivanje.", "", false, "Nepotvrđeno");
    add("Prolazak kroz prepreke", "Postupak iz vodiča", "Posebni postupci",
        "Originalni tajni uslov postoji: vožnja unazad uz sirenu i sudar sa odgovarajućim pokretnim objektom na Mediterraneo ili Mystic Peaks. Kasniji prolazak kroz prepreku zahteva dovoljnu brzinu i ograničene delove tih staza; ne važi za svaku ogradu. Zahtev za McLaren F1 i brzine 60/80 mph iz vodiča nisu potvrđeni. Postupak nije zasebno isproban u vožnji.", "", false, "Postupak");
    add("Pogrešan kod za dinosauruse", "rexrage", "Ispravke vodiča",
        "REXRAGE sa slike nije na originalnom spisku ove verzije. Za dinosauruse izaberi stavku REXHOUR u kategoriji „Efekti i saobraćaj“.", "", false, "Ispravka");
    add("Ford Indigo", "red racer", "Ispravke vodiča",
        "RED RACER nije prepoznat kod u ovoj Special Edition verziji. Ford Indigo je običan automobil: vrati obična vozila ako je uključena GO zamena i izaberi ga u Player Car meniju.", "", false, "Ispravka");
    return entries;
}

NSTextField* label(NSString* value, NSFont* font) {
    NSTextField* view = [NSTextField wrappingLabelWithString:value];
    view.font = font;
    view.textColor = NSColor.labelColor;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}
}

@interface NFSIISECheatsPanelController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate> {
    std::vector<CheatEntry> _entries;
    std::vector<std::size_t> _visible;
    nfs2se::cheats::Snapshot _state;
}
@property(nonatomic, strong) NSTableView* table;
@property(nonatomic, strong) NSSearchField* search;
@property(nonatomic, strong) NSPopUpButton* categories;
@property(nonatomic, strong) NSTextField* detailTitle;
@property(nonatomic, strong) NSTextField* detailCode;
@property(nonatomic, strong) NSTextField* detailStatus;
@property(nonatomic, strong) NSTextView* detailBody;
@property(nonatomic, strong) NSTextField* feedback;
@property(nonatomic, strong) NSButton* activateButton;
@property(nonatomic, strong) NSButton* resetButton;
@property(nonatomic, strong) NSTimer* refreshTimer;
@property(nonatomic, weak) NSWindow* gameWindow;
- (void)togglePanel:(id)sender;
- (void)refresh;
- (void)stop;
@end

@implementation NFSIISECheatsPanelController
- (instancetype)init {
    NSPanel* panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 800, 610)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:panel];
    if (!self) return nil;
    _entries = makeEntries();
    panel.title = @"Need for Speed II SE — Kodovi";
    panel.minSize = NSMakeSize(760, 590);
    panel.releasedWhenClosed = NO;
    panel.hidesOnDeactivate = YES;
    panel.floatingPanel = YES;
    panel.becomesKeyOnlyIfNeeded = NO;
    panel.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorCanJoinAllSpaces;
    [panel center];

    NSView* content = panel.contentView;
    NSTextField* title = label(@"Skriveni automobili i kodovi", [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold]);
    NSTextField* intro = label(@"Kodove aktiviraj iz glavnog menija igre, pre trke. Otvori ovaj panel tasterom F12 ili ⌘⇧K.", [NSFont systemFontOfSize:13]);
    intro.textColor = NSColor.secondaryLabelColor;
    NSTextField* searchLabel = label(@"Pretraga", [NSFont systemFontOfSize:13]);
    self.search = [[NSSearchField alloc] initWithFrame:NSZeroRect];
    self.search.placeholderString = @"Naziv, kod ili opis";
    self.search.delegate = self;
    self.search.translatesAutoresizingMaskIntoConstraints = NO;
    self.search.accessibilityLabel = @"Pretraži kodove";
    self.search.sendsSearchStringImmediately = YES;
    self.categories = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.categories addItemsWithTitles:@[@"Sve kategorije", @"Automobili", @"GO vozila i predmeti", @"Efekti i saobraćaj", @"Staze i prikaz", @"Posebni postupci", @"Ispravke vodiča"]];
    self.categories.target = self;
    self.categories.action = @selector(filterChanged:);
    self.categories.translatesAutoresizingMaskIntoConstraints = NO;
    self.categories.accessibilityLabel = @"Kategorija kodova";
    NSView* body = [NSView new];
    body.translatesAutoresizingMaskIntoConstraints = NO;

    NSScrollView* tableScroll = [NSScrollView new];
    tableScroll.translatesAutoresizingMaskIntoConstraints = NO;
    tableScroll.hasVerticalScroller = YES;
    tableScroll.borderType = NSBezelBorder;
    self.table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    self.table.delegate = self;
    self.table.dataSource = self;
    self.table.rowHeight = 29;
    self.table.usesAlternatingRowBackgroundColors = YES;
    self.table.allowsEmptySelection = YES;
    self.table.allowsMultipleSelection = NO;
    self.table.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
    self.table.accessibilityLabel = @"Spisak kodova i skrivenih vozila";
    self.table.doubleAction = @selector(activateSelected:);
    self.table.target = self;
    for (NSArray<NSString*>* spec in @[@[@"title", @"Naziv"], @[@"code", @"Kod"], @[@"status", @"Status"]]) {
        NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:spec[0]];
        column.title = spec[1];
        column.width = [spec[0] isEqualToString:@"title"] ? 183 : [spec[0] isEqualToString:@"code"] ? 88 : 92;
        column.minWidth = [spec[0] isEqualToString:@"title"] ? 145 : 70;
        [self.table addTableColumn:column];
    }
    tableScroll.documentView = self.table;
    NSBox* separator = [NSBox new];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    NSView* detail = [NSView new];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailTitle = label(@"", [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold]);
    self.detailCode = label(@"", [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightMedium]);
    self.detailCode.textColor = NSColor.secondaryLabelColor;
    self.detailStatus = label(@"", [NSFont systemFontOfSize:12 weight:NSFontWeightMedium]);
    self.detailStatus.textColor = NSColor.secondaryLabelColor;
    NSScrollView* descriptionScroll = [NSScrollView new];
    descriptionScroll.translatesAutoresizingMaskIntoConstraints = NO;
    descriptionScroll.hasVerticalScroller = YES;
    descriptionScroll.drawsBackground = NO;
    self.detailBody = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 260, 260)];
    self.detailBody.editable = NO;
    self.detailBody.selectable = YES;
    self.detailBody.richText = NO;
    self.detailBody.drawsBackground = NO;
    self.detailBody.font = [NSFont systemFontOfSize:13];
    self.detailBody.textColor = NSColor.labelColor;
    self.detailBody.textContainerInset = NSMakeSize(0, 4);
    self.detailBody.verticallyResizable = YES;
    self.detailBody.horizontallyResizable = NO;
    self.detailBody.autoresizingMask = NSViewWidthSizable;
    self.detailBody.textContainer.widthTracksTextView = YES;
    self.detailBody.textContainer.lineFragmentPadding = 0;
    self.detailBody.accessibilityLabel = @"Opis i uputstvo za izabrani kod";
    descriptionScroll.documentView = self.detailBody;
    NSTextField* effectNote = label(@"Kodovi uključuju efekat; ponovni unos ga ne isključuje. Koristi „Ukloni efekte“ za povratak.", [NSFont systemFontOfSize:12]);
    effectNote.textColor = NSColor.secondaryLabelColor;
    self.feedback = label(@"", [NSFont systemFontOfSize:12]);
    self.feedback.accessibilityLabel = @"Dostupnost aktiviranja i poruka igre";
    self.feedback.maximumNumberOfLines = 3;
    self.activateButton = [NSButton buttonWithTitle:@"Aktiviraj" target:self action:@selector(activateSelected:)];
    self.activateButton.bezelStyle = NSBezelStyleRounded;
    self.activateButton.keyEquivalent = @"\r";
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.activateButton.accessibilityLabel = @"Aktiviraj izabrani kod u igri";
    self.resetButton = [NSButton buttonWithTitle:@"Ukloni efekte" target:self action:@selector(resetEffects:)];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetButton.toolTip = @"Uklanja privremene efekte i zamene vozila; zadržava otključane automobile, staze i Slot opciju.";
    NSButton* closeButton = [NSButton buttonWithTitle:@"Nazad u igru" target:self action:@selector(returnToGame:)];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    closeButton.keyEquivalent = @"\e";

    for (NSView* view in @[title, intro, searchLabel, self.search, self.categories, body, self.feedback, self.resetButton, closeButton, self.activateButton]) [content addSubview:view];
    for (NSView* view in @[tableScroll, separator, detail]) [body addSubview:view];
    for (NSView* view in @[self.detailTitle, self.detailCode, self.detailStatus, descriptionScroll, effectNote]) [detail addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:content.topAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [intro.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],
        [intro.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [intro.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [searchLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [searchLabel.centerYAnchor constraintEqualToAnchor:self.search.centerYAnchor],
        [self.search.topAnchor constraintEqualToAnchor:intro.bottomAnchor constant:14],
        [self.search.leadingAnchor constraintEqualToAnchor:searchLabel.trailingAnchor constant:9],
        [self.search.heightAnchor constraintEqualToConstant:28],
        [self.categories.leadingAnchor constraintEqualToAnchor:self.search.trailingAnchor constant:12],
        [self.categories.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [self.categories.centerYAnchor constraintEqualToAnchor:self.search.centerYAnchor],
        [self.categories.widthAnchor constraintEqualToConstant:207],
        [body.topAnchor constraintEqualToAnchor:self.search.bottomAnchor constant:12],
        [body.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [body.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [body.bottomAnchor constraintEqualToAnchor:self.feedback.topAnchor constant:-12],
        [tableScroll.topAnchor constraintEqualToAnchor:body.topAnchor],
        [tableScroll.bottomAnchor constraintEqualToAnchor:body.bottomAnchor],
        [tableScroll.leadingAnchor constraintEqualToAnchor:body.leadingAnchor],
        [tableScroll.widthAnchor constraintEqualToAnchor:body.widthAnchor multiplier:0.56],
        [separator.leadingAnchor constraintEqualToAnchor:tableScroll.trailingAnchor constant:12],
        [separator.topAnchor constraintEqualToAnchor:body.topAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:body.bottomAnchor],
        [separator.widthAnchor constraintEqualToConstant:1],
        [detail.leadingAnchor constraintEqualToAnchor:separator.trailingAnchor constant:12],
        [detail.trailingAnchor constraintEqualToAnchor:body.trailingAnchor],
        [detail.topAnchor constraintEqualToAnchor:body.topAnchor],
        [detail.bottomAnchor constraintEqualToAnchor:body.bottomAnchor],
        [self.detailTitle.topAnchor constraintEqualToAnchor:detail.topAnchor constant:4],
        [self.detailTitle.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor],
        [self.detailTitle.trailingAnchor constraintEqualToAnchor:detail.trailingAnchor],
        [self.detailCode.topAnchor constraintEqualToAnchor:self.detailTitle.bottomAnchor constant:8],
        [self.detailCode.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor],
        [self.detailCode.trailingAnchor constraintEqualToAnchor:detail.trailingAnchor],
        [self.detailStatus.topAnchor constraintEqualToAnchor:self.detailCode.bottomAnchor constant:6],
        [self.detailStatus.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor],
        [self.detailStatus.trailingAnchor constraintEqualToAnchor:detail.trailingAnchor],
        [descriptionScroll.topAnchor constraintEqualToAnchor:self.detailStatus.bottomAnchor constant:10],
        [descriptionScroll.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor],
        [descriptionScroll.trailingAnchor constraintEqualToAnchor:detail.trailingAnchor],
        [descriptionScroll.bottomAnchor constraintEqualToAnchor:effectNote.topAnchor constant:-12],
        [effectNote.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor],
        [effectNote.trailingAnchor constraintEqualToAnchor:detail.trailingAnchor],
        [effectNote.bottomAnchor constraintEqualToAnchor:detail.bottomAnchor constant:-3],
        [self.feedback.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.feedback.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [self.feedback.heightAnchor constraintGreaterThanOrEqualToConstant:36],
        [self.feedback.bottomAnchor constraintEqualToAnchor:self.activateButton.topAnchor constant:-10],
        [self.resetButton.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.resetButton.centerYAnchor constraintEqualToAnchor:self.activateButton.centerYAnchor],
        [closeButton.trailingAnchor constraintEqualToAnchor:self.activateButton.leadingAnchor constant:-10],
        [closeButton.centerYAnchor constraintEqualToAnchor:self.activateButton.centerYAnchor],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [self.activateButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-17],
        [self.activateButton.widthAnchor constraintGreaterThanOrEqualToConstant:115]
    ]];
    [self filterChanged:nil];
    [self refresh];
    __weak NFSIISECheatsPanelController* weakSelf = self;
    self.refreshTimer = [NSTimer timerWithTimeInterval:0.35 repeats:YES block:^(NSTimer* timer) {
        (void)timer;
        [weakSelf refresh];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.refreshTimer forMode:NSRunLoopCommonModes];
    return self;
}

- (const CheatEntry*)selectedEntry {
    const NSInteger row = self.table.selectedRow;
    return row >= 0 && static_cast<std::size_t>(row) < _visible.size() ? &_entries[_visible[static_cast<std::size_t>(row)]] : nullptr;
}

- (BOOL)isActive:(const CheatEntry&)entry {
    return !entry.action.empty() && std::find(_state.activeCodes.begin(), _state.activeCodes.end(), entry.action) != _state.activeCodes.end();
}

- (NSString*)statusForEntry:(const CheatEntry&)entry {
    if ([self isActive:entry]) {
        if (entry.action == "fzr2000" || entry.action == "tombstone" || entry.action == "bomber" || entry.action == "hollywood" || entry.action == "slot") return @"Otključano";
        return @"Aktivno";
    }
    return text(entry.availability);
}

- (void)filterChanged:(id)sender {
    (void)sender;
    std::string previous;
    if (const auto* entry = [self selectedEntry]) previous = entry->code;
    _visible.clear();
    NSString* query = [self.search.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* category = self.categories.titleOfSelectedItem;
    for (std::size_t i = 0; i < _entries.size(); ++i) {
        const auto& entry = _entries[i];
        if (self.categories.indexOfSelectedItem > 0 && ![category isEqualToString:text(entry.category)]) continue;
        NSString* haystack = [NSString stringWithFormat:@"%@ %@ %@ %@", text(entry.title), text(entry.code), text(entry.category), text(entry.detail)];
        if (query.length && ![haystack localizedStandardContainsString:query]) continue;
        _visible.push_back(i);
    }
    [self.table reloadData];
    NSInteger selection = _visible.empty() ? -1 : 0;
    for (std::size_t i = 0; i < _visible.size(); ++i) if (_entries[_visible[i]].code == previous) selection = static_cast<NSInteger>(i);
    if (selection >= 0) [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:static_cast<NSUInteger>(selection)] byExtendingSelection:NO];
    else [self.table deselectAll:nil];
    [self updateDetails];
}

- (void)controlTextDidChange:(NSNotification*)notification {
    (void)notification;
    [self filterChanged:nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView {
    (void)tableView;
    return static_cast<NSInteger>(_visible.size());
}

- (NSView*)tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)column row:(NSInteger)row {
    const auto& entry = _entries[_visible[static_cast<std::size_t>(row)]];
    NSTableCellView* cell = [tableView makeViewWithIdentifier:column.identifier owner:self];
    if (!cell) {
        cell = [NSTableCellView new];
        cell.identifier = column.identifier;
        NSTextField* field = [NSTextField labelWithString:@""];
        field.translatesAutoresizingMaskIntoConstraints = NO;
        field.lineBreakMode = NSLineBreakByTruncatingTail;
        field.font = [NSFont systemFontOfSize:12];
        [cell addSubview:field];
        cell.textField = field;
        [NSLayoutConstraint activateConstraints:@[
            [field.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:5],
            [field.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-5],
            [field.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
    }
    NSString* value = [column.identifier isEqualToString:@"title"] ? text(entry.title) : [column.identifier isEqualToString:@"code"] ? text(entry.code) : [self statusForEntry:entry];
    cell.textField.stringValue = value;
    cell.textField.toolTip = value;
    cell.textField.font = [column.identifier isEqualToString:@"code"] ? [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular] : [NSFont systemFontOfSize:12 weight:([self isActive:entry] ? NSFontWeightSemibold : NSFontWeightRegular)];
    cell.textField.textColor = entry.supported ? NSColor.labelColor : NSColor.secondaryLabelColor;
    cell.accessibilityLabel = value;
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification*)notification {
    (void)notification;
    [self updateDetails];
}

- (void)updateDetails {
    const auto* entry = [self selectedEntry];
    const bool canApply = _state.menuReady && _state.singleRace && !_state.pending;
    self.resetButton.enabled = canApply;
    self.activateButton.enabled = canApply && entry && entry->supported && !entry->action.empty();
    self.activateButton.title = entry && [self isActive:*entry] ? @"Primeni ponovo" : @"Aktiviraj";
    if (!entry) {
        self.detailTitle.stringValue = _visible.empty() ? @"Nema rezultata" : @"Izaberi kod";
        self.detailCode.stringValue = @"";
        self.detailStatus.stringValue = @"";
        self.detailBody.string = _visible.empty() ? @"Promeni pretragu ili izaberi drugu kategoriju." : @"Izaberi stavku iz spiska sa leve strane da pročitaš opis i aktiviraš kod.";
    } else {
        self.detailTitle.stringValue = text(entry->title);
        self.detailCode.stringValue = text(entry->code);
        self.detailStatus.stringValue = [self statusForEntry:*entry];
        if (![self.detailBody.string isEqualToString:text(entry->detail)]) {
            self.detailBody.string = text(entry->detail);
            [self.detailBody scrollRangeToVisible:NSMakeRange(0, 0)];
        }
    }
    NSString* readiness = !_state.menuReady ? @"Vrati se u meni igre da aktiviraš kodove." : !_state.singleRace ? @"Za aktiviranje izaberi Single Race u igri." : _state.pending ? @"Igra obrađuje izabrani kod…" : @"Spremno za aktiviranje. „Ukloni efekte“ zadržava otključane automobile, staze i Slot opciju.";
    self.feedback.stringValue = _state.feedback.empty() ? readiness : [NSString stringWithFormat:@"%@\n%@", readiness, text(_state.feedback)];
}

- (void)refresh {
    auto next = nfs2se::cheats::snapshot();
    const bool changed = next.menuReady != _state.menuReady || next.singleRace != _state.singleRace || next.pending != _state.pending || next.feedback != _state.feedback || next.activeCodes != _state.activeCodes;
    _state = std::move(next);
    if (changed) {
        const NSInteger selected = self.table.selectedRow;
        [self.table reloadData];
        if (!_visible.empty()) {
            const NSUInteger row = selected >= 0 && static_cast<std::size_t>(selected) < _visible.size() ? static_cast<NSUInteger>(selected) : 0;
            [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }
    [self updateDetails];
}

- (void)togglePanel:(id)sender {
    (void)sender;
    if (self.window.visible) {
        [self returnToGame:nil];
        return;
    }
    NSWindow* current = NSApp.keyWindow;
    if (current && current != self.window && ![current isKindOfClass:NSPanel.class]) self.gameWindow = current;
    [self refresh];
    if (self.table.selectedRow < 0 && !_visible.empty())
        [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.search];
}

- (void)returnToGame:(id)sender {
    (void)sender;
    [self.window orderOut:nil];
    if (self.gameWindow) [self.gameWindow makeKeyAndOrderFront:nil];
    else for (NSWindow* window in NSApp.windows) {
        if (window != self.window && window.visible && ![window isKindOfClass:NSPanel.class]) {
            [window makeKeyAndOrderFront:nil];
            break;
        }
    }
}

- (void)activateSelected:(id)sender {
    if (sender == self.table && self.table.clickedRow < 0) return;
    [self refresh];
    const auto* entry = [self selectedEntry];
    if (!entry || !entry->supported || entry->action.empty() || !_state.menuReady || !_state.singleRace || _state.pending) return;
    if (nfs2se::cheats::queue(entry->action)) [self returnToGame:nil];
    else [self refresh];
}

- (void)resetEffects:(id)sender {
    (void)sender;
    [self refresh];
    if (!_state.menuReady || !_state.singleRace || _state.pending) return;
    if (nfs2se::cheats::queue("reset")) [self returnToGame:nil];
    else [self refresh];
}

- (void)stop {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    [self.window orderOut:nil];
}
@end

namespace nfs2se::cheats {
namespace {
NFSIISECheatsPanelController* controller;
NSMenuItem* rootMenuItem;
id keyMonitor;
}

void installMenu() {
    if (controller) return;
    controller = [NFSIISECheatsPanelController new];
    if (!NSApp.mainMenu) NSApp.mainMenu = [[NSMenu alloc] initWithTitle:@""];
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Kodovi"];
    NSMenuItem* showItem = [[NSMenuItem alloc] initWithTitle:@"Skriveni automobili i kodovi…" action:@selector(togglePanel:) keyEquivalent:@"k"];
    showItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    showItem.target = controller;
    [menu addItem:showItem];
    NSMenuItem* hint = [[NSMenuItem alloc] initWithTitle:@"Panel možeš otvoriti i tasterom F12" action:nil keyEquivalent:@""];
    hint.enabled = NO;
    [menu addItem:hint];
    rootMenuItem = [[NSMenuItem alloc] initWithTitle:@"Kodovi" action:nil keyEquivalent:@""];
    rootMenuItem.submenu = menu;
    [NSApp.mainMenu addItem:rootMenuItem];
    keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskKeyUp) handler:^NSEvent*(NSEvent* event) {
        NSString* characters = event.charactersIgnoringModifiers;
        const bool isF12 = event.keyCode == 111 || (characters.length && [characters characterAtIndex:0] == NSF12FunctionKey);
        if (!isF12) return event;
        if (event.type == NSEventTypeKeyDown) {
            if (!event.isARepeat) [controller togglePanel:nil];
        }
        return nil; // Consume both halves so F12 never reaches the original game.
    }];
}

void shutdownMenu() {
    if (keyMonitor) [NSEvent removeMonitor:keyMonitor];
    keyMonitor = nil;
    if (rootMenuItem) [NSApp.mainMenu removeItem:rootMenuItem];
    rootMenuItem = nil;
    [controller stop];
    controller = nil;
}
}
