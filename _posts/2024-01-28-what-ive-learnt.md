---
title: "Reflections on My Journey: What I've Learnt, Part 1"
date: 2024-01-28
---

### _Nearly four years have passed since I embarked on my quest to become a professional software engineer. So, what nuggets of wisdom have I gathered along the way?_

Join me as I take a nostalgic stroll down memory lane, revisiting some of the early code I penned as a fledgling programmer. It’s fascinating to reflect on the moments when I was blissfully unaware of the vast expanse of knowledge yet to be discovered in the world of coding.

One of my inaugural projects – a genuine learning endeavour – was a GUI application designed to download and extract MP3s from YouTube videos. At that time, I had a close friend who was already well-versed in the programming realm; he was busy maintaining his first mobile app. When I shared my ambitious project with him, he issued a challenge: "Why not use the JSON from exported Firefox bookmarks to download an entire list of MP3s?" This was the moment I realised the motivation that comes from having a concrete goal, especially with others invested in your success. I proudly crafted my little Python Tkinter app to meet his expectations. I recall even dabbling in multithreading to showcase download progress—though if I’m honest, I barely grasped the concept at the time! My forays into Python classes were equally naive: I was using them, but lacked any real understanding.

Looking back at my early code, one aspect stands out: everything was crammed into a single file. Sure, it wasn't a colossal program, but there were various distinct functionalities all located in that one space. I had a window for downloading MP3s, a separate one for MP4s, and the main interface.

```python
LARGE_FONT = 'Verdana 14 bold'
MEDIUM_FONT = 'Verdana 10'
SMALL_FONT = 'Verdana 8 bold'
title = 'PYMPv0.4'
TITLE_FONT = 'Courier 54 bold'


class Pymp(tk.Tk):

    var1 = None
    var2 = None
    url = None
    status_bar = None

    def __init__(self, *args, **kwargs):
        tk.Tk.__init__(self, *args, **kwargs)
        tk.Tk.wm_title(self, title)

        container = tk.Frame(self)
        container.pack(side="top", fill="both", expand="True")
        container.grid_rowconfigure(0, weight=1)
        container.grid_columnconfigure(0, weight=1)

        str_var1 = tk.StringVar()
        str_var2 = tk.StringVar()
        str_var3 = tk.StringVar()
        Pymp.var1 = str_var1
        Pymp.var1.set('')
        Pymp.var2 = str_var2
        Pymp.var2.set('')
        Pymp.status_bar = str_var3
        Pymp.status_bar.set('Ready')

        self.frames = {}

        for F in (Disclaimer, MenuWindow, Pymp3, Pymp4):
            frame = F(container, self)
            self.frames[F] = frame
            frame.grid(row=0, column=0, sticky="nsew")

        self.show_frame(Disclaimer)

    def show_frame(self, cont):
        frame = self.frames[cont]
        frame.tkraise()
```

It's glaringly obvious that I was closely tracing a tutorial, especially with most of my constants named so conventionally—except for the `title`, of course!

Another glaring oversight was my lack of understanding regarding `self`. The reason I ended up with multiple class attributes set to `None`, only to later assign desired values (e.g. `Pymp.var1 = str_var1`), was purely due to my ignorance of simply using `self` when working with class instances. It’s amusing to think back on this now, though it’s an odd yet interesting approach to programming, surely born from a mix of trial and error and relentless Googling (clearly not enough of the latter!). After some tweaking (see the refactored code below), I believe there’s nothing inherently wrong with that initial version of the code, but I simply can’t recall enough about Tkinter to definitively say how I’d approach it differently now:

```python
class Pymp(tk.Tk):

    def __init__(self, *args, **kwargs):
        super().__init__(self, *args, **kwargs)
        super().wm_title(self, TITLE)

        container = tk.Frame(self)
        container.pack(side="top", fill="both", expand="True")
        container.grid_rowconfigure(0, weight=1)
        container.grid_columnconfigure(0, weight=1)

        self.text1 = tk.StringVar(self, value="")
        self.text2 = tk.StringVar(self, value="")
        self.status_bar = tk.StringVar()
        self.status_bar.set('Ready')

        self.frames = {}
        for window in (Disclaimer, MenuWindow, Pymp3, Pymp4):
            frame = window(container, self)
            self.frames[window] = frame
            frame.grid(row=0, column=0, sticky="nsew")

        self.show_frame(Disclaimer)

    def show_frame(self, frame):
        frame = self.frames[frame]
        frame.tkraise()
```

It's hard to pinpoint exactly when the concept of objects truly took hold in my understanding, but it was a gradual journey leading to that eureka moment while reading [Mastering Object-Oriented Python by Steven F Lott](https://www.amazon.com/Mastering-Object-oriented-Python-Steven-Lott/dp/1783280972), a couple of years after I cobbled together that initial project.

A significant part of this learning curve involved grasping the lifecycle of an object, recognising when various “dunder” methods—like `__init__`, `__new__`, `__set_attr__`, and `__set_attribute__`—are invoked, and understanding when and why to override certain methods. I also delved into Python's Method Resolution Order (MRO) and its critical role when leveraging mixins and multiple inheritance.

Another excellent and eye-opening book I read around the same time was [Clean Architectures in Python by Leo Geordiani](https://leanpub.com/clean-architectures-in-python) who was actually a colleague of mine at the time, and a huge source of inspiration.

The most profound lesson I've learnt over these past four years? There is always more to learn!
