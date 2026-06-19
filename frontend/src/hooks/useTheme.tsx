import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { theme as antdTheme } from 'antd';
import type { ThemeConfig } from 'antd';

// ─── SHANUTECHX brand palette ────────────────────────────────────────────────
//  brand-bg          #03061D   deepest background layer
//  brand-surface     #0B0E2A   card base before glass overlay
//  brand-violet      #7A43D7   primary / gradient start
//  brand-violet-deep #6443B8   gradient mid-tone
//  brand-cyan        #23B6D3   gradient end, links, success
//  brand-cyan-bright #36A1C7   hover accents
//  brand-text        #FAFAFA   primary text on dark
// ─────────────────────────────────────────────────────────────────────────────

const STORAGE_DARK  = 'dark-mode';
const STORAGE_ULTRA = 'isUltraDarkThemeEnabled';

function readBool(key: string, fallback: boolean): boolean {
  const raw = localStorage.getItem(key);
  if (raw === null) return fallback;
  return raw === 'true';
}

function applyDom(isDark: boolean, isUltra: boolean) {
  document.body.setAttribute('class', isDark ? 'dark' : 'light');
  if (isUltra) {
    document.documentElement.setAttribute('data-theme', 'ultra-dark');
  } else {
    document.documentElement.removeAttribute('data-theme');
  }
  const msg = document.getElementById('message');
  if (msg) msg.className = isDark ? 'dark' : 'light';

  // Apply brand gradient backdrop so glass panels have something to refract.
  if (isDark) {
    document.body.style.background = isUltra
      ? 'radial-gradient(ellipse at 20% 10%, #0B0E2A 0%, #03061D 55%, #000 100%)'
      : 'radial-gradient(ellipse at 20% 10%, #0D1035 0%, #03061D 60%, #020416 100%)';
    document.body.style.fontFamily = "'Inter', 'Manrope', system-ui, sans-serif";
  } else {
    document.body.style.background = '';
    document.body.style.fontFamily = "'Inter', 'Manrope', system-ui, sans-serif";
  }
}

// Apply before React mounts to avoid flash-of-unstyled-content.
const initialDark  = readBool(STORAGE_DARK, true);
const initialUltra = readBool(STORAGE_ULTRA, false);
applyDom(initialDark, initialUltra);

// ─── Dark (SHANUTECHX glass) tokens ─────────────────────────────────────────
const DARK_TOKENS = {
  colorBgBase:       '#0B0E2A',
  colorBgLayout:     '#03061D',
  // Semi-transparent so AntD surfaces can become glass tiles:
  colorBgContainer:  'rgba(11,14,42,0.55)',
  colorBgElevated:   'rgba(45,47,85,0.45)',
  // Brand primaries:
  colorPrimary:      '#7A43D7',
  colorLink:         '#23B6D3',
  colorInfo:         '#23B6D3',
  colorSuccess:      '#23B6D3',
  colorText:         '#FAFAFA',
  colorTextSecondary:'rgba(250,250,250,0.65)',
  colorBorder:       'rgba(255,255,255,0.12)',
  colorBorderSecondary: 'rgba(255,255,255,0.08)',
  borderRadius:      12,
  fontFamily:        "'Inter', 'Manrope', system-ui, sans-serif",
};

const ULTRA_DARK_TOKENS = {
  colorBgBase:       '#000',
  colorBgLayout:     '#000',
  colorBgContainer:  'rgba(6,8,26,0.62)',
  colorBgElevated:   'rgba(15,17,40,0.55)',
  colorPrimary:      '#7A43D7',
  colorLink:         '#23B6D3',
  colorInfo:         '#23B6D3',
  colorSuccess:      '#23B6D3',
  colorText:         '#FAFAFA',
  colorTextSecondary:'rgba(250,250,250,0.55)',
  colorBorder:       'rgba(255,255,255,0.08)',
  colorBorderSecondary: 'rgba(255,255,255,0.05)',
  borderRadius:      12,
  fontFamily:        "'Inter', 'Manrope', system-ui, sans-serif",
};

// ─── Layout tokens ───────────────────────────────────────────────────────────
const DARK_LAYOUT_TOKENS = {
  bodyBg:       '#03061D',
  headerBg:     'rgba(3,6,29,0.7)',
  headerColor:  '#FAFAFA',
  footerBg:     '#03061D',
  siderBg:      'rgba(11,14,42,0.70)',
  triggerBg:    'rgba(122,67,215,0.18)',
  triggerColor: '#FAFAFA',
};

const ULTRA_DARK_LAYOUT_TOKENS = {
  bodyBg:       '#000',
  headerBg:     'rgba(0,0,0,0.80)',
  headerColor:  '#FAFAFA',
  footerBg:     '#000',
  siderBg:      'rgba(6,8,26,0.80)',
  triggerBg:    'rgba(122,67,215,0.12)',
  triggerColor: '#FAFAFA',
};

// ─── Menu tokens ─────────────────────────────────────────────────────────────
const DARK_MENU_TOKENS = {
  darkItemBg:       'rgba(11,14,42,0.70)',
  darkSubMenuItemBg:'rgba(3,6,29,0.60)',
  darkPopupBg:      'rgba(11,14,42,0.88)',
  darkItemSelectedBg: 'rgba(122,67,215,0.22)',
  darkItemSelectedColor: '#FAFAFA',
  darkItemActiveBg:  'rgba(122,67,215,0.14)',
  itemHoverColor:    '#23B6D3',
};

const ULTRA_DARK_MENU_TOKENS = {
  darkItemBg:       'rgba(6,8,26,0.80)',
  darkSubMenuItemBg:'rgba(0,0,0,0.70)',
  darkPopupBg:      'rgba(6,8,26,0.92)',
  darkItemSelectedBg: 'rgba(122,67,215,0.18)',
  darkItemSelectedColor: '#FAFAFA',
  darkItemActiveBg:  'rgba(122,67,215,0.10)',
  itemHoverColor:    '#23B6D3',
};

// ─── Card tokens ─────────────────────────────────────────────────────────────
const DARK_CARD_TOKENS = {
  colorBorderSecondary: 'rgba(255,255,255,0.10)',
  colorBgContainer:     'rgba(11,14,42,0.55)',
  boxShadow:
    '0 8px 32px rgba(3,6,29,0.55), inset 0 1px 0 rgba(255,255,255,0.06)',
  borderRadius: 16,
};

const ULTRA_DARK_CARD_TOKENS = {
  colorBorderSecondary: 'rgba(255,255,255,0.06)',
  colorBgContainer:     'rgba(6,8,26,0.62)',
  boxShadow:
    '0 8px 32px rgba(0,0,0,0.70), inset 0 1px 0 rgba(255,255,255,0.04)',
  borderRadius: 16,
};

const STATISTIC_TOKENS = {
  contentFontSize: 17,
  titleFontSize:   11,
};

// ─── Button tokens ───────────────────────────────────────────────────────────
const DARK_BUTTON_TOKENS = {
  // Primary buttons pick up colorPrimary; just tweak the shadow.
  primaryShadow: '0 4px 16px rgba(122,67,215,0.45)',
  defaultBg:     'rgba(255,255,255,0.06)',
  defaultBorderColor: 'rgba(255,255,255,0.16)',
  defaultColor:  '#FAFAFA',
};

// ─────────────────────────────────────────────────────────────────────────────
export function buildAntdThemeConfig(isDark: boolean, isUltra: boolean): ThemeConfig {
  if (!isDark) {
    return {
      algorithm: antdTheme.defaultAlgorithm,
      token: {
        colorPrimary: '#7A43D7',
        colorLink:    '#23B6D3',
        colorInfo:    '#23B6D3',
        borderRadius: 12,
        fontFamily:   "'Inter', 'Manrope', system-ui, sans-serif",
      },
      components: {
        Statistic: STATISTIC_TOKENS,
      },
    };
  }

  return {
    algorithm: antdTheme.darkAlgorithm,
    token:     isUltra ? ULTRA_DARK_TOKENS     : DARK_TOKENS,
    components: {
      Layout:  isUltra ? ULTRA_DARK_LAYOUT_TOKENS : DARK_LAYOUT_TOKENS,
      Menu:    isUltra ? ULTRA_DARK_MENU_TOKENS   : DARK_MENU_TOKENS,
      Card:    isUltra ? ULTRA_DARK_CARD_TOKENS   : DARK_CARD_TOKENS,
      Button:  DARK_BUTTON_TOKENS,
      Statistic: STATISTIC_TOKENS,
      Modal: {
        contentBg: isUltra ? 'rgba(6,8,26,0.88)' : 'rgba(11,14,42,0.82)',
        headerBg:  'transparent',
        borderRadius: 16,
      },
      Drawer: {
        colorBgElevated: isUltra ? 'rgba(6,8,26,0.92)' : 'rgba(11,14,42,0.88)',
      },
      Table: {
        colorBgContainer: 'transparent',
        headerBg: isUltra ? 'rgba(6,8,26,0.80)' : 'rgba(11,14,42,0.70)',
        rowHoverBg: 'rgba(122,67,215,0.08)',
      },
      Input: {
        colorBgContainer: 'rgba(255,255,255,0.05)',
        colorBorder:      'rgba(255,255,255,0.14)',
        hoverBorderColor: '#7A43D7',
        activeBorderColor:'#7A43D7',
      },
      Select: {
        colorBgContainer:      'rgba(255,255,255,0.05)',
        colorBorder:           'rgba(255,255,255,0.14)',
        optionSelectedBg:      'rgba(122,67,215,0.18)',
        colorBgElevated:       isUltra ? 'rgba(6,8,26,0.95)' : 'rgba(11,14,42,0.92)',
      },
      Tag: {
        colorBgContainer: 'rgba(122,67,215,0.14)',
        colorBorder:      'rgba(122,67,215,0.30)',
      },
      Progress: {
        colorSuccess: '#23B6D3',
      },
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
export function pauseAnimationsUntilLeave(elementId: string): void {
  document.documentElement.setAttribute('data-theme-animations', 'off');
  const el = document.getElementById(elementId);
  if (!el) return;
  const restore = () => {
    document.documentElement.removeAttribute('data-theme-animations');
    el.removeEventListener('mouseleave', restore);
    el.removeEventListener('touchend',   restore);
  };
  el.addEventListener('mouseleave', restore);
  el.addEventListener('touchend',   restore);
}

// ─────────────────────────────────────────────────────────────────────────────
interface ThemeContextValue {
  isDark:  boolean;
  isUltra: boolean;
  toggleTheme: () => void;
  toggleUltra: () => void;
  antdThemeConfig: ThemeConfig;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [isDark,  setIsDark]  = useState<boolean>(initialDark);
  const [isUltra, setIsUltra] = useState<boolean>(initialUltra);

  useEffect(() => {
    applyDom(isDark, isUltra);
    localStorage.setItem(STORAGE_DARK,  String(isDark));
    localStorage.setItem(STORAGE_ULTRA, String(isUltra));
  }, [isDark, isUltra]);

  const toggleTheme = useCallback(() => setIsDark((v)  => !v), []);
  const toggleUltra = useCallback(() => setIsUltra((v) => !v), []);

  const antdThemeConfig = useMemo(
    () => buildAntdThemeConfig(isDark, isUltra),
    [isDark, isUltra],
  );

  const value = useMemo<ThemeContextValue>(
    () => ({ isDark, isUltra, toggleTheme, toggleUltra, antdThemeConfig }),
    [isDark, isUltra, toggleTheme, toggleUltra, antdThemeConfig],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used inside <ThemeProvider>');
  return ctx;
}
