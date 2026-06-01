/** Zgodne z `Engine/GameContext.swift` + `UI/PixelCanvas.swift` */
export type PixelColor =
  | 'black'
  | 'darkGray'
  | 'road'
  | 'grass'
  | 'white'
  | 'cyan'
  | 'magenta'
  | 'green'
  | 'yellow'
  | 'red'
  | 'navy'
  | 'wood'
  | 'woodLight'
  | 'woodDark'
  | 'floorA'
  | 'floorB';

export const PIXEL_PALETTE: Record<PixelColor, string> = {
  black: 'rgb(13, 13, 26)',
  darkGray: 'rgb(46, 46, 61)',
  road: 'rgb(56, 56, 77)',
  grass: 'rgb(26, 89, 46)',
  white: 'rgb(235, 240, 255)',
  cyan: 'rgb(51, 242, 255)',
  magenta: 'rgb(255, 64, 191)',
  green: 'rgb(64, 255, 115)',
  yellow: 'rgb(255, 235, 64)',
  red: 'rgb(255, 77, 77)',
  navy: 'rgb(15, 20, 56)',
  wood: 'rgb(82, 51, 31)',
  woodLight: 'rgb(184, 122, 66)',
  woodDark: 'rgb(148, 97, 51)',
  floorA: 'rgb(26, 28, 46)',
  floorB: 'rgb(18, 20, 36)',
};

export const GRID_WIDTH = 160;
export const GRID_HEIGHT = 90;
export const PIXEL_TOP_INSET = 10;

export type DrawCommand =
  | {type: 'rect'; x: number; y: number; width: number; height: number; color: PixelColor}
  | {type: 'text'; value: string; x: number; y: number; color: PixelColor};
