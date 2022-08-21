FROM alpine:latest

RUN apk add git make cmake build-base
RUN mkdir -p /etc/deps
RUN git clone https://luajit.org/git/luajit.git /etc/deps/luajit
RUN cd /etc/deps/luajit && make && make install
RUN git clone https://github.com/google/brotli.git /etc/deps/brotli
RUN mkdir -p /etc/deps/brotli/out && \
    cd /etc/deps/brotli/out && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./installed .. && \
    cmake --build . --config Release --target install
RUN mv /etc/deps/brotli/out/installed/lib/*.so /usr/local/lib
RUN ln -sf luajit-2.1.0-beta3 /usr/local/bin/luajit
RUN wget https://luarocks.org/releases/luarocks-3.8.0.tar.gz
RUN tar zxpf luarocks-3.8.0.tar.gz
RUN cd luarocks-3.8.0 && \
    ./configure --with-lua-include=/usr/local/include && \
    make && \
    make install

WORKDIR /etc/code
ENTRYPOINT [ "/bin/sh" ]