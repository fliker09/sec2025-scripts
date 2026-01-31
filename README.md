# Solar Eclipse Conference 2025: 'Remote control of Sony cameras for solar eclipses' by Alexandru Barbovschi

This repository contains the scripts which were used to conduct the benchmarks for the presentation. The structure of this repo is as follows:

* `diy_usb_remote_shutter_trigger` - contains schematics, source code and reference images for a DIY USB Remote Shutter Trigger device. It is used in 3 of the scripts in the `sony_mark_III` folder. My copy was built using an Arduino Nano microcontroller.
* `generations_reference_images` - contains reference images to help distinguish between "old" and "new" generations of Sony cameras' firmware. At the moment of writing this, the scripts were tested only for the "old" gen cameras.
* `nikon_d610` - contains benchmark scripts for Nikon D610, a camera which was used as a reference one.
* `raw_jpeg_mode_settings` - contains images with instructions how to properly set the camera for the scripts which are meant to benchmark 'RAW & JPEG' shooting mode.
* `sony_mark_I_II` - contains scripts to benchmark Sony cameras of Mark I and II, which are in reference to the A7 series. For the presentation only A7S I and A7S II were tested (note - A7S II is not available for testing anymore, it has been sold off).
* `sony_mark_III` - contains scripts to benchmark Sony cameras of Mark III, which is in reference to the A7 series. For the presentation only A7 III was tested (note - A7R III is now available for testings).
* `prepare_usb.sh` - script which is required to run before each run of the benchmark scripts for Sony cameras. It configures the camera to be in a state similar to one used to shoot Baily's Beads (which is done before the imminent totality).

These scripts have been tested on a Linux system only, but it should be rather trivial to run them on Mac OS X and even Windows with the help of WSL (personally haven't tried either, would be happy to receive any reports about these platforms!). You must have these utilities installed:

`bash`, `awk`, `sed`, `bc`, `curl`, `jq`, `tmux` (I am not listing the full list because the rest of them are pretty much standard utilities for any Unix-alike OS).

Warning for Mac OS X users - these utilities might behave in a slightly different way than on Linux (e.g. `date` might not return nanoseconds).

The most important tool is, of course, `gphoto2`. You can install it from your package manager and be done with it. But if might be not the latest available version. In this case you might need to compile it yourself. If you run a Debian-based system like Ubuntu - clone this repo and run the script:

[https://github.com/fliker09/gphoto2-updater]()

No need to uninstall your current version - this script will install it in parallel and take precedence over the system's version. Personally used it a number of Debian and Ubuntu systems, older and newer, and it worked without any additional efforts.

All scripts have detailed comments, which hopefully will explain their inner workings. If you have any suggestions for improvements and/or clarifications - please open an `Issue` here on GitHub! If you would like to get in touch and discuss collabaration (e.g. testing a new camera) - please contact me directly at `alex_dot_sec2025_at_capturetheuniverse_dot_com`!

A typical scenario for a benchmark looks like this:

1. Set all the relevant options on your camera (Manual mode, RAW file format, no noise subtraction, etc.);
2. Connect your camera to the computer by USB cable;
3. Open a terminal session in this repo's folder;
4. Let's prepare a validation function: ``validate_sony() { ls -1 *.ARW *.jPG | wc -l; echo; for i in *.ARW *.JPG; do echo $i; exiftool $i | grep -i 'shutter speed'; done }``. Just copy it into your terminal session and press Enter - we will use this function later on;
5. Run `prepare_usb.sh` script and wait for it to finish;
6. Run a script of your choice, depending on your camera and chosen approach;
7. To validate the script's run, let's validate the files it downloaded from camera (where applicable! Nikon scripts won't download anything and the same goes for the `Ykush` variant for the Sony cameras). Run the `validate_sony` function we added to our terminal session previously. It will output the number of files downloaded (by default it should be 15) and then the list of files with the corresponding shutter speed. Please look through and check that they have the expected values!
8. Remove the downloaded files by running `rm *.ARW *.JPG 2>/dev/null` command (you can also make this into a function, for the convenience sake).
9. Run steps 5 to 8 nine more times. If no issues encountered - the benchmark can be declared successful! Collect the running time for each round if you want to run some statistical math.

The benchmarks which were conducted for the SEC2025 presentation (along with all the technical details) will be published soon, either here or on my blog website. Also going to publish my production scripts for shooting a TSE from A to Z in a separate repo here:

[https://github.com/fliker09/gphoto2-eclipse-automation]()
