![Angular and related icons animated on Commodore Vic-20](https://github.com/davervw/angular-vic20/blob/main/media/angular_vic20.gif?raw=true)

![Angular screen saver](https://github.com/davervw/angular-vic20/blob/main/media/angular%20screen%20saver.gif?raw=true)

Instructions:

    Get out your Vic-20 (or emulator)
    Transfer project files or d64 to it
    LOAD"STARTUP",8
    RUN

* ANGULAR (PRG) tiled icons
* ANGULAR2 (PRG) interactive multi-color palette changes
* ANGULAR3 (PRG) random placement on 8x16 pixel grid, avoiding overlap
* ANGULAR3.1 (PRG) random placement on finer 2x1 pixel grid, avoiding overlap on 8x16 color pixel
* ANGULAR4 (PRG) animated movement of icons bumping into each other avoiding overlap 
* BOUNDING BOX (PRG) showing boxes drawn avoiding overlap, keeping only first 10, showing collisions with flash
* BOUNCE RUNNER (PRG) runs the assembly language port of ANGULAR4 for increased performance

Utilizes LOADHIRES20 from the [hires-vic-20](https://github.com/davervw/hires-vic-20) project