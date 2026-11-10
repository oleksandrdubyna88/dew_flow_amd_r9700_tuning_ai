#!/usr/bin/env python3
"""Review sheets for keyframes, made with Pillow only (no server, no GPU): what a person looks at before a GPU job, and what a repair is placed on.

  sheets.py contact <out.png> <picture>... [--cols 3] [--tile-width 512]        the pictures in a grid, each labelled with the start of its file name
  sheets.py crops <out.png> <picture>:<x0>,<y0>,<x1>,<y1>... [--tile-width 512]  crops (fractions of each picture), enlarged, in one row
  sheets.py grid <out.png> <picture>:<x0>,<y0>,<x1>,<y1>... [--step 0.02]         the same crops with a coordinate grid every --step of the WHOLE picture, labelled
                                                                                 every fifth line: where the boxes of masked_repaint.py are read off
  sheets.py mark <out.png> "<picture>|<caption>|<x0>,<y0>,<x1>,<y1>;..." ...     each picture with red frames and a caption, two per row: shows a person where a
                                                                                 problem is (the boxes may be empty)
A box is fractions of the picture's width and height, 0-1, with x0 < x1 and y0 < y1."""
import argparse
import os
import sys

TILE_HEIGHT_RATIO = 9 / 16  # a contact-sheet cell is 16:9, like the clips
GRID_LABEL_EVERY = 5
MARK_WIDTH = 1280
MAX_PICTURES = 200  # one canvas holds every tile: 200 at the default 512 px is about 0.5 GB of RGB, more is refused before a picture is opened


class SheetError(Exception):
    pass


def parse_box(text):
    try:
        box = tuple(float(v) for v in text.split(","))
    except ValueError:
        raise SheetError(f"a box is four numbers x0,y0,x1,y1; got {text!r}") from None
    if len(box) != 4 or not (0 <= box[0] < box[2] <= 1 and 0 <= box[1] < box[3] <= 1):
        raise SheetError(f"a box is four fractions 0-1 with x0 < x1 and y0 < y1; got {text!r}")
    return box


def parse_crop(arg):
    path, sep, box = arg.rpartition(":")
    if not sep or not path:
        raise SheetError(f"a crop is <picture>:<x0>,<y0>,<x1>,<y1>; got {arg!r}")
    return path, parse_box(box)


def _open(path):
    from PIL import Image
    return Image.open(path).convert("RGB")


def _pixel_box(size, box):
    width, height = size
    x0, y0, x1, y1 = box
    return int(x0 * width), int(y0 * height), max(int(x1 * width), int(x0 * width) + 1), max(int(y1 * height), int(y0 * height) + 1)


def _row(tiles, out):
    from PIL import Image
    width = sum(t.width for t in tiles)
    sheet = Image.new("RGB", (width, max(t.height for t in tiles)), "black")
    x = 0
    for tile in tiles:
        sheet.paste(tile, (x, 0))
        x += tile.width
    sheet.save(out)
    return sheet.size


def contact(out, pictures, cols, tile_width):
    if len(pictures) > MAX_PICTURES:
        raise SheetError(f"at most {MAX_PICTURES} pictures per sheet (one canvas holds them all); got {len(pictures)}: split them")
    from PIL import Image, ImageDraw
    tile_height = int(tile_width * TILE_HEIGHT_RATIO)
    rows = (len(pictures) + cols - 1) // cols
    sheet = Image.new("RGB", (tile_width * cols, tile_height * rows), "black")
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(pictures):
        x, y = (i % cols) * tile_width, (i // cols) * tile_height
        picture = _open(path)
        picture.thumbnail((tile_width, tile_height))
        sheet.paste(picture, (x + (tile_width - picture.width) // 2, y))
        draw.rectangle((x, y, x + 150, y + 16), fill="black")
        draw.text((x + 3, y + 2), os.path.basename(path)[:20], fill="white")
    sheet.save(out)
    return sheet.size


def crops(out, items, tile_width):
    tiles = []
    for path, box in items:
        picture = _open(path)
        tile = picture.crop(_pixel_box(picture.size, box))
        tiles.append(tile.resize((tile_width, max(1, round(tile_width * tile.height / tile.width)))))
    return _row(tiles, out)


def _grid_tile(path, box, step, tile_width):
    from PIL import ImageDraw
    picture = _open(path)
    width, height = picture.size
    x0, y0, x1, y1 = box
    tile = picture.crop(_pixel_box(picture.size, box))
    scale = tile_width / tile.width
    tile = tile.resize((tile_width, max(1, round(tile.height * scale))))
    draw = ImageDraw.Draw(tile)
    first, last = int(x0 / step), int(x1 / step) + 1
    for i in range(first, last + 1):
        x = (i * step - x0) * width * scale
        draw.line((x, 0, x, tile.height), fill=(0, 255, 0) if i % GRID_LABEL_EVERY == 0 else (0, 110, 0))
        if i % GRID_LABEL_EVERY == 0:
            draw.text((x + 2, 2), f"{i * step:.2f}", fill="yellow")
    for j in range(int(y0 / step), int(y1 / step) + 2):
        y = (j * step - y0) * height * scale
        draw.line((0, y, tile.width, y), fill=(0, 255, 0) if j % GRID_LABEL_EVERY == 0 else (0, 110, 0))
        if j % GRID_LABEL_EVERY == 0:
            draw.text((2, y + 2), f"{j * step:.2f}", fill="yellow")
    draw.text((5, tile.height - 14), os.path.basename(path), fill="white")
    return tile


def grid(out, items, step, tile_width):
    if not 0.005 <= step <= 0.25:
        raise SheetError("--step is a fraction of the picture, 0.005-0.25")
    return _row([_grid_tile(path, box, step, tile_width) for path, box in items], out)


def parse_mark(arg):
    parts = arg.split("|")
    if len(parts) != 3 or not parts[0]:
        raise SheetError(f"a mark is \"<picture>|<caption>|<boxes>\" with boxes x0,y0,x1,y1 separated by ';' (may be empty); got {arg!r}")
    return parts[0], parts[1], [parse_box(b) for b in parts[2].split(";") if b]


def mark(out, items):
    from PIL import Image, ImageDraw
    tiles = []
    for path, caption, boxes in items:
        picture = _open(path)
        height = round(MARK_WIDTH * picture.height / picture.width)
        picture = picture.resize((MARK_WIDTH, height))
        draw = ImageDraw.Draw(picture)
        for box in boxes:
            draw.rectangle(_pixel_box(picture.size, box), outline=(255, 30, 30), width=5)
        draw.rectangle((0, 0, 9 * len(caption) + 20, 30), fill="black")
        draw.text((10, 8), caption, fill="white")
        tiles.append(picture)
    row_height = max(t.height for t in tiles)
    sheet = Image.new("RGB", (MARK_WIDTH * 2, row_height * ((len(tiles) + 1) // 2)), "black")
    for i, tile in enumerate(tiles):
        sheet.paste(tile, ((i % 2) * MARK_WIDTH, (i // 2) * row_height))
    sheet.save(out)
    return sheet.size


def build_parser():
    parser = argparse.ArgumentParser(prog="sheets.py", description="Review sheets for keyframes (Pillow only).")
    sub = parser.add_subparsers(dest="command", required=True)
    c = sub.add_parser("contact")
    c.add_argument("out")
    c.add_argument("pictures", nargs="+")
    c.add_argument("--cols", type=int, default=3)
    c.add_argument("--tile-width", type=int, default=512)
    for name in ("crops", "grid"):
        p = sub.add_parser(name)
        p.add_argument("out")
        p.add_argument("items", nargs="+", metavar="picture:x0,y0,x1,y1")
        p.add_argument("--tile-width", type=int, default=512 if name == "crops" else 640)
        if name == "grid":
            p.add_argument("--step", type=float, default=0.02)
    m = sub.add_parser("mark")
    m.add_argument("out")
    m.add_argument("items", nargs="+", metavar="picture|caption|boxes")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        if getattr(args, "tile_width", 512) < 16 or getattr(args, "cols", 1) < 1:
            raise SheetError("--tile-width is at least 16 and --cols at least 1")
        if args.command == "contact":
            size = contact(args.out, args.pictures, args.cols, args.tile_width)
        elif args.command == "crops":
            size = crops(args.out, [parse_crop(a) for a in args.items], args.tile_width)
        elif args.command == "grid":
            size = grid(args.out, [parse_crop(a) for a in args.items], args.step, args.tile_width)
        else:
            size = mark(args.out, [parse_mark(a) for a in args.items])
    except SheetError as error:
        print(f"sheets: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"sheets: FILE: {error}", file=sys.stderr)
        return 1
    print(f"sheets: {args.command} -> {args.out} ({size[0]}x{size[1]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
