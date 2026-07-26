from PIL import Image

files = [
    "D:/Sankar Giri R/Project Start Up/temple_book_app/Screenshots/Temple_Book_Icon.png",
#    "D:/Sankar Giri R/Project Start Up/temple_book_app/Screenshots/Register_page.png",
#    "D:/Sankar Giri R/Project Start Up/temple_book_app/Screenshots/login_page_email.png"
]

sizes = {
  #  "phone": (1080500, 1920),
    "tablet7": (512, 512),
  #  "tablet10": (1920, 1080),
}

for file in files:
    img = Image.open(file).convert("RGB")

    for name, size in sizes.items():
        canvas = Image.new("RGB", size, "white")

        copy = img.copy()
        copy.thumbnail(size, Image.LANCZOS)

        x = (size[0] - copy.width) // 2
        y = (size[1] - copy.height) // 2

        canvas.paste(copy, (x, y))
        canvas.save(file.replace(".png", f"_{name}.png"))