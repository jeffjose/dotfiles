## How to make gifs


1. Cut the video (lossless-cut)
- https://github.com/mifi/lossless-cut

2. Convert to 30fps
```
ffmpeg -i video.webm -filter:v fps=fps=30 out.webm
```

3. Extract frames
```
ffmpeg -i out.webm out.%04d.png
```

4. Convert png to gif (gifski)
```
cargo install gifski

gifski -W 1440 animated.gif *.png
```
