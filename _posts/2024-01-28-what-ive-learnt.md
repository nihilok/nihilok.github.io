---
title: "What I've Learnt, Part 1"
date: 2024-01-28
---

### _It's been nearly 4 years since I started on the road to becoming a professional software engineer. What have I learnt in this time?_

I thought it might be quite fun to start by taking a look back at some of the code I wrote very early on and go over anything that I was completely oblivious of at the time and reflect on how it felt to be stepping into the big wide world of programming.

One of the first projects I took on as a learning exercise was a GUI program to download and extract MP3s from YouTube videos. I have a very close friend who was a few steps further along the road to me at the time, as he had already taken the plunge and was already maintaining his first mobile app, and when I told him what I was doing he offered me a useful criteria - he said it should take the JSON from exported Firefox bookmarks and download the whole list of MP3s. It was upon receiving this challenge, I think, that I realised how much of a buzz it is to have an extrinsic goal to be working towards, with other stakeholders involved. I succeeded in making my little Python Tkinter app do what he had asked. I even had some multithreading in there if I remember rightly so that I could show the progress of the downloads, but I probably had very little idea of what that entailed under the hood, and had just found something on StackOverflow that pointed me towards multithreading. One thing I remember definitely not understanding at this time was classes in Python. I was using them for sure, but the way I was using them was extremely naive.

The first thing I notice looking back the code, is how everything is in the same file! Admittedly, it's not a huge program, but still, there's plenty of different things going on in this file. There's a window to download MP3s, a window to download MP4s and a main window.

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

You can see that I was most likely very closely following some tutorial, by the way that most of my constants are conventionally named except the `title`!

The next thing that jumps out is my lack of awareness/understanding of `self`. The reason that there are several class attributes set to None which are then later set to the value I want (e.g. `Pymp.var1 = str_var1`) is that I didn't know I could just refer to `self` when dealing with instances of classes. I find this hilarious now, but it is quite an interesting approach, I suppose, that I think most likely evolved from bashing my head against error messages and furiously Googling (but not well enough, clearly!) until something worked! After a couple of tweaks (below) there is nothing _too_ smelly about this code I suppose (in isolation at least), but I don't remember enough about Tkinter to say for sure if I would do it any differently from this "fixed" version:

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

I'm not sure when the idea of objects solidified itself in my head, but it was definitely something that I learnt about gradually, finally nailing all the pieces together when I read _Mastering Object-Oriented Python_ (Steven F Lott) a couple of years after the above example project was first cobbled together.

A big part of this was understanding the lifecycle of an object, and when different "dunder" methods are called, such as `__init__`, but also `__new__`, `__set_attr__`, `__set_attribute__` etc. and what they do, and how/why to override them in certain specific cases. Another fundamental thing I learnt about in this regard is Python's MRO, or Method Resolution Order, and how important this is when using mixins and multiple inheritance.

