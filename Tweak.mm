#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <substrate.h>
#import <mach-o/dyld.h>

// =====================================================
// Roblox Offsets - Version: version-80c7b8e578f241ff
// =====================================================
namespace offsets {
    // Critical offsets for executor
    inline constexpr uintptr_t ScriptContext = 0x3F0;
    inline constexpr uintptr_t LocalPlayer = 0x130;
    inline constexpr uintptr_t Name = 0xB0;
    inline constexpr uintptr_t Parent = 0x68;
    inline constexpr uintptr_t Children = 0x70;
    inline constexpr uintptr_t Workspace = 0x178;
    
    // Pointers
    inline constexpr uintptr_t FakeDataModelPointer = 0x7C75728;
    inline constexpr uintptr_t FakeDataModelToDataModel = 0x1C0;
    inline constexpr uintptr_t DataModelDeleterPointer = 0x7C75730;
    inline constexpr uintptr_t TaskSchedulerPointer = 0x7D33708;
    inline constexpr uintptr_t JobsPointer = 0x7D338E0;
    inline constexpr uintptr_t VisualEnginePointer = 0x775E8D0;
    inline constexpr uintptr_t PlayerConfigurerPointer = 0x7C53948;
    
    // Game state
    inline constexpr uintptr_t GameLoaded = 0x630;
    inline constexpr uintptr_t PlaceId = 0x198;
    inline constexpr uintptr_t GameId = 0x190;
    
    // Player
    inline constexpr uintptr_t UserId = 0x2C8;
    inline constexpr uintptr_t DisplayName = 0x130;
    inline constexpr uintptr_t CharacterAppearanceId = 0x2B8;
    inline constexpr uintptr_t Team = 0x290;
    
    // Humanoid
    inline constexpr uintptr_t Health = 0x194;
    inline constexpr uintptr_t MaxHealth = 0x1B4;
    inline constexpr uintptr_t WalkSpeed = 0x1D4;
    inline constexpr uintptr_t JumpPower = 0x1B0;
    inline constexpr uintptr_t HipHeight = 0x1A0;
    
    // Scripts
    inline constexpr uintptr_t LocalScriptByteCode = 0x1A8;
    inline constexpr uintptr_t ModuleScriptByteCode = 0x150;
    inline constexpr uintptr_t RunContext = 0x148;
    inline constexpr uintptr_t Sandboxed = 0xC5;
}

// =====================================================
// Lua State Structures
// =====================================================
typedef struct lua_State lua_State;

typedef int (*lua_getglobal_t)(lua_State *L, const char *name);
typedef int (*luaL_loadstring_t)(lua_State *L, const char *s);
typedef int (*lua_pcall_t)(lua_State *L, int nargs, int nresults, int errfunc);
typedef const char *(*lua_tolstring_t)(lua_State *L, int idx, size_t *len);
typedef void (*lua_settop_t)(lua_State *L, int idx);
typedef void (*lua_pushstring_t)(lua_State *L, const char *s);
typedef void (*lua_pushcclosure_t)(lua_State *L, void *fn, int n);
typedef void (*lua_setglobal_t)(lua_State *L, const char *name);
typedef int (*lua_gettop_t)(lua_State *L);

// Function pointers
lua_getglobal_t orig_lua_getglobal = NULL;
luaL_loadstring_t orig_luaL_loadstring = NULL;
lua_pcall_t orig_lua_pcall = NULL;
lua_tolstring_t orig_lua_tolstring = NULL;
lua_settop_t orig_lua_settop = NULL;
lua_pushstring_t orig_lua_pushstring = NULL;
lua_pushcclosure_t orig_lua_pushcclosure = NULL;
lua_setglobal_t orig_lua_setglobal = NULL;
lua_gettop_t orig_lua_gettop = NULL;

// Global state
static lua_State *g_LuaState = NULL;
static uintptr_t g_BaseAddress = 0;
static WKWebView *g_WebView = NULL;
static bool g_Initialized = false;

// =====================================================
// Utility Functions
// =====================================================

uintptr_t getBaseAddress() {
    if (g_BaseAddress != 0) return g_BaseAddress;
    
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "RobloxPlayer") != NULL || strstr(name, "Roblox") != NULL) {
            const struct mach_header *header = _dyld_get_image_header(i);
            g_BaseAddress = (uintptr_t)header;
            NSLog(@"[Executor] ✓ Roblox base address: 0x%lx", g_BaseAddress);
            return g_BaseAddress;
        }
    }
    
    NSLog(@"[Executor] ✗ Failed to find Roblox base address");
    return 0;
}

// =====================================================
// DataModel & ScriptContext
// =====================================================

uintptr_t getDataModel() {
    uintptr_t base = getBaseAddress();
    if (!base) return 0;
    
    @try {
        // Method 1: FakeDataModelPointer
        uintptr_t fakeDataModelPtr = *(uintptr_t*)(base + offsets::FakeDataModelPointer);
        if (fakeDataModelPtr) {
            uintptr_t dataModel = *(uintptr_t*)(fakeDataModelPtr + offsets::FakeDataModelToDataModel);
            if (dataModel) {
                NSLog(@"[Executor] ✓ DataModel: 0x%lx", dataModel);
                return dataModel;
            }
        }
        
        // Method 2: VisualEnginePointer
        uintptr_t visualEnginePtr = *(uintptr_t*)(base + offsets::VisualEnginePointer);
        if (visualEnginePtr) {
            uintptr_t visualEngine = *(uintptr_t*)(visualEnginePtr + 0x10);
            if (visualEngine) {
                uintptr_t dataModel1 = *(uintptr_t*)(visualEngine + 0x700);
                if (dataModel1) {
                    uintptr_t dataModel = *(uintptr_t*)(dataModel1 + 0x1C0);
                    if (dataModel) {
                        NSLog(@"[Executor] ✓ DataModel (via VisualEngine): 0x%lx", dataModel);
                        return dataModel;
                    }
                }
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[Executor] Exception in getDataModel: %@", exception.reason);
    }
    
    NSLog(@"[Executor] ✗ Failed to find DataModel");
    return 0;
}

lua_State* getScriptContext() {
    uintptr_t dataModel = getDataModel();
    if (!dataModel) return NULL;
    
    @try {
        uintptr_t scriptContext = *(uintptr_t*)(dataModel + offsets::ScriptContext);
        if (!scriptContext) {
            NSLog(@"[Executor] ✗ ScriptContext is null");
            return NULL;
        }
        
        // Common offsets for lua_State in ScriptContext
        // Try multiple offsets as they may vary
        uintptr_t possibleOffsets[] = {0x140, 0x138, 0x148, 0x150, 0x130};
        
        for (int i = 0; i < 5; i++) {
            lua_State *L = *(lua_State**)(scriptContext + possibleOffsets[i]);
            if (L && (uintptr_t)L > 0x100000000) { // Basic sanity check
                NSLog(@"[Executor] ✓ Lua State found at offset 0x%lx: %p", possibleOffsets[i], L);
                return L;
            }
        }
        
        NSLog(@"[Executor] ✗ Could not find valid Lua State");
    }
    @catch (NSException *exception) {
        NSLog(@"[Executor] Exception in getScriptContext: %@", exception.reason);
    }
    
    return NULL;
}

// =====================================================
// Lua Execution
// =====================================================

void sendToWebView(NSString *type, NSString *message) {
    if (!g_WebView) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *escapedMsg = [message stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        escapedMsg = [escapedMsg stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        
        NSString *js = [NSString stringWithFormat:@"window.show%@('%@');", type, escapedMsg];
        [g_WebView evaluateJavaScript:js completionHandler:nil];
    });
}

void executeLuaScript(NSString *script) {
    @try {
        if (!g_LuaState) {
            NSLog(@"[Executor] Attempting to initialize Lua State...");
            g_LuaState = getScriptContext();
        }
        
        if (!g_LuaState) {
            NSLog(@"[Executor] ✗ Lua State unavailable");
            sendToWebView(@"Error", @"Lua State not initialized. Wait for game to load.");
            return;
        }
        
        const char *scriptCStr = [script UTF8String];
        NSLog(@"[Executor] Executing script (length: %lu)", (unsigned long)script.length);
        
        // Save stack top
        int top = orig_lua_gettop ? orig_lua_gettop(g_LuaState) : 0;
        
        // Load script
        int loadResult = orig_luaL_loadstring(g_LuaState, scriptCStr);
        
        if (loadResult != 0) {
            // Load error
            const char *error = orig_lua_tolstring(g_LuaState, -1, NULL);
            NSString *errorStr = [NSString stringWithUTF8String:error ?: "Unknown load error"];
            NSLog(@"[Executor] ✗ Load error: %@", errorStr);
            
            orig_lua_settop(g_LuaState, top);
            sendToWebView(@"Error", [NSString stringWithFormat:@"Load Error: %@", errorStr]);
            return;
        }
        
        // Execute script
        int execResult = orig_lua_pcall(g_LuaState, 0, 0, 0);
        
        if (execResult != 0) {
            // Execution error
            const char *error = orig_lua_tolstring(g_LuaState, -1, NULL);
            NSString *errorStr = [NSString stringWithUTF8String:error ?: "Unknown execution error"];
            NSLog(@"[Executor] ✗ Execution error: %@", errorStr);
            
            orig_lua_settop(g_LuaState, top);
            sendToWebView(@"Error", [NSString stringWithFormat:@"Runtime Error: %@", errorStr]);
            return;
        }
        
        // Success
        NSLog(@"[Executor] ✓ Script executed successfully");
        sendToWebView(@"Success", @"Script executed successfully");
        
        // Restore stack
        orig_lua_settop(g_LuaState, top);
    }
    @catch (NSException *exception) {
        NSLog(@"[Executor] ✗ Exception: %@", exception.reason);
        sendToWebView(@"Error", [NSString stringWithFormat:@"Exception: %@", exception.reason]);
    }
}

// =====================================================
// WebView Handler
// =====================================================

@interface ScriptMessageHandler : NSObject <WKScriptMessageHandler>
@end

@implementation ScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController 
      didReceiveScriptMessage:(WKScriptMessage *)message {
    
    if ([message.name isEqualToString:@"execute"]) {
        if ([message.body isKindOfClass:[NSString class]]) {
            NSString *script = (NSString *)message.body;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                executeLuaScript(script);
            });
        }
    }
    else if ([message.name isEqualToString:@"clear"]) {
        NSLog(@"[Executor] Console cleared");
    }
    else if ([message.name isEqualToString:@"getStatus"]) {
        uintptr_t dataModel = getDataModel();
        bool gameLoaded = false;
        
        if (dataModel) {
            gameLoaded = *(bool*)(dataModel + offsets::GameLoaded);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *status = [NSString stringWithFormat:
                @"window.updateStatus({ready:%@,luaState:'%p',base:'0x%lx',gameLoaded:%@});",
                g_LuaState ? @"true" : @"false",
                g_LuaState,
                g_BaseAddress,
                gameLoaded ? @"true" : @"false"
            ];
            [g_WebView evaluateJavaScript:status completionHandler:nil];
        });
    }
    else if ([message.name isEqualToString:@"inject"]) {
        // Re-initialize Lua State
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            g_LuaState = getScriptContext();
            sendToWebView(@"Success", g_LuaState ? @"Injected successfully" : @"Injection failed");
        });
    }
}

@end

// =====================================================
// Pan Gesture for WebView
// =====================================================

@interface DraggableWebView : WKWebView
@property (nonatomic, assign) CGPoint lastLocation;
@end

@implementation DraggableWebView

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:self.superview];
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.lastLocation = self.center;
    }
    
    self.center = CGPointMake(self.lastLocation.x + translation.x,
                             self.lastLocation.y + translation.y);
}

@end

// =====================================================
// WebView Setup
// =====================================================

void setupWebView() {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            WKUserContentController *contentController = [[WKUserContentController alloc] init];
            
            ScriptMessageHandler *handler = [[ScriptMessageHandler alloc] init];
            [contentController addScriptMessageHandler:handler name:@"execute"];
            [contentController addScriptMessageHandler:handler name:@"clear"];
            [contentController addScriptMessageHandler:handler name:@"getStatus"];
            [contentController addScriptMessageHandler:handler name:@"inject"];
            
            config.userContentController = contentController;
            config.preferences.javaScriptEnabled = YES;
            
            // Create draggable WebView
            CGRect screen = [[UIScreen mainScreen] bounds];
            CGRect frame = CGRectMake(10, 100, screen.size.width - 20, screen.size.height * 0.6);
            
            g_WebView = [[DraggableWebView alloc] initWithFrame:frame configuration:config];
            g_WebView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.98];
            g_WebView.layer.cornerRadius = 20;
            g_WebView.layer.masksToBounds = YES;
            g_WebView.layer.borderWidth = 2;
            g_WebView.layer.borderColor = [UIColor colorWithRed:0 green:1 blue:0.53 alpha:0.5].CGColor;
            
            // Add pan gesture
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] 
                initWithTarget:g_WebView action:@selector(handlePan:)];
            [g_WebView addGestureRecognizer:pan];
            
            // Load HTML UI
            NSString *html = @R"HTML(
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background: #0a0a0a;
            color: #fff;
            padding: 15px;
            overflow: hidden;
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
            padding-bottom: 10px;
            border-bottom: 2px solid #00ff88;
        }
        h1 {
            font-size: 20px;
            color: #00ff88;
            font-weight: 700;
        }
        .status {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 12px;
        }
        .dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #ff4444;
            animation: pulse 2s infinite;
        }
        .dot.ready {
            background: #00ff88;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        textarea {
            width: 100%;
            height: 280px;
            background: #1a1a1a;
            color: #00ff88;
            border: 2px solid #333;
            border-radius: 12px;
            padding: 12px;
            font-family: 'Menlo', 'Monaco', 'Courier New', monospace;
            font-size: 13px;
            resize: none;
            outline: none;
        }
        textarea:focus {
            border-color: #00ff88;
        }
        .buttons {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 10px;
            margin-top: 12px;
        }
        button {
            padding: 14px;
            background: linear-gradient(135deg, #00ff88, #00cc70);
            color: #000;
            border: none;
            border-radius: 10px;
            font-weight: 700;
            font-size: 14px;
            cursor: pointer;
            transition: transform 0.1s;
        }
        button:active {
            transform: scale(0.95);
        }
        .btn-clear {
            background: linear-gradient(135deg, #ff4444, #cc0000);
            color: #fff;
        }
        .btn-inject {
            background: linear-gradient(135deg, #4444ff, #0000cc);
            color: #fff;
        }
        .console {
            background: #000;
            border: 2px solid #333;
            border-radius: 10px;
            padding: 10px;
            margin-top: 12px;
            height: 90px;
            overflow-y: auto;
            font-size: 11px;
            font-family: monospace;
        }
        .console div {
            padding: 2px 0;
            border-bottom: 1px solid #111;
        }
        .success { color: #00ff88; }
        .error { color: #ff4444; }
        .info { color: #4488ff; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Roblox Executor</h1>
        <div class="status">
            <div class="dot" id="statusDot"></div>
            <span id="statusText">Waiting...</span>
        </div>
    </div>
    
    <textarea id="code" placeholder="-- Enter Lua code here&#10;print('Hello from iOS Executor!')&#10;game:GetService('Players').LocalPlayer.Character.Humanoid.WalkSpeed = 50"></textarea>
    
    <div class="buttons">
        <button onclick="execute()">▶ Execute</button>
        <button class="btn-clear" onclick="clear()">🗑 Clear</button>
        <button class="btn-inject" onclick="inject()">💉 Inject</button>
    </div>
    
    <div class="console" id="console"></div>
    
    <script>
        function execute() {
            const code = document.getElementById('code').value.trim();
            if (!code) {
                showError('Code is empty');
                return;
            }
            window.webkit.messageHandlers.execute.postMessage(code);
        }
        
        function clear() {
            document.getElementById('code').value = '';
            document.getElementById('console').innerHTML = '';
        }
        
        function inject() {
            window.webkit.messageHandlers.inject.postMessage('');
        }
        
        function log(msg, type) {
            const console = document.getElementById('console');
            const time = new Date().toLocaleTimeString();
            console.innerHTML += `<div class="${type}">[${time}] ${msg}</div>`;
            console.scrollTop = console.scrollHeight;
        }
        
        function showError(msg) { log('❌ ' + msg, 'error'); }
        function showSuccess(msg) { log('✓ ' + msg, 'success'); }
        function showInfo(msg) { log('ℹ ' + msg, 'info'); }
        
        function updateStatus(data) {
            const dot = document.getElementById('statusDot');
            const text = document.getElementById('statusText');
            
            if (data.ready && data.gameLoaded) {
                dot.className = 'dot ready';
                text.textContent = 'Ready';
            } else if (data.ready) {
                dot.className = 'dot';
                text.textContent = 'Game Loading...';
            } else {
                dot.className = 'dot';
                text.textContent = 'Not Ready';
            }
        }
        
        // Update status every 2 seconds
        setInterval(() => {
            window.webkit.messageHandlers.getStatus.postMessage('');
        }, 2000);
        
        // Initial status check
        setTimeout(() => {
            window.webkit.messageHandlers.getStatus.postMessage('');
        }, 500);
    </script>
</body>
</html>
)HTML";
            
            [g_WebView loadHTMLString:html baseURL:nil];
            
            // Add to window
            UIWindow *window = [[UIApplication sharedApplication] windows].firstObject;
            if (!window) {
                window = [[UIApplication sharedApplication] keyWindow];
            }
            
            if (window) {
                [window addSubview:g_WebView];
                NSLog(@"[Executor] ✓ WebView added to window");
            } else {
                NSLog(@"[Executor] ✗ No window available");
            }
        }
    });
}

// =====================================================
// Initialization
// =====================================================

void initializeLuaFunctions() {
    // Try to find Lua functions
    orig_luaL_loadstring = (luaL_loadstring_t)dlsym(RTLD_DEFAULT, "luaL_loadstring");
    orig_lua_pcall = (lua_pcall_t)dlsym(RTLD_DEFAULT, "lua_pcall");
    orig_lua_tolstring = (lua_tolstring_t)dlsym(RTLD_DEFAULT, "lua_tolstring");
    orig_lua_settop = (lua_settop_t)dlsym(RTLD_DEFAULT, "lua_settop");
    orig_lua_getglobal = (lua_getglobal_t)dlsym(RTLD_DEFAULT, "lua_getglobal");
    orig_lua_pushstring = (lua_pushstring_t)dlsym(RTLD_DEFAULT, "lua_pushstring");
    orig_lua_setglobal = (lua_setglobal_t)dlsym(RTLD_DEFAULT, "lua_setglobal");
    orig_lua_gettop = (lua_gettop_t)dlsym(RTLD_DEFAULT, "lua_gettop");
    
    NSLog(@"[Executor] Lua functions loaded:");
    NSLog(@"  - luaL_loadstring: %p", orig_luaL_loadstring);
    NSLog(@"  - lua_pcall: %p", orig_lua_pcall);
    NSLog(@"  - lua_tolstring: %p", orig_lua_tolstring);
    NSLog(@"  - lua_settop: %p", orig_lua_settop);
}

__attribute__((constructor))
static void initialize() {
    NSLog(@"==============================================");
    NSLog(@"[Executor] 🚀 Dylib Injected!");
    NSLog(@"[Executor] Version: version-80c7b8e578f241ff");
    NSLog(@"==============================================");
    
    // Get base address
    getBaseAddress();
    
    // Initialize Lua functions
    initializeLuaFunctions();
    
    // Setup UI after delay (wait for Roblox to initialize)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), 
                   dispatch_get_main_queue(), ^{
        setupWebView();
        
        // Try to get Lua State
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            sleep(2);
            g_LuaState = getScriptContext();
            if (g_LuaState) {
                NSLog(@"[Executor] ✓ Initial Lua State captured");
            }
        });
    });
    
    NSLog(@"[Executor] ✓ Initialization complete");
}
