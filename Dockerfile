# FROM archlinux:base-devel
# 支持 arm64 架构
FROM menci/archlinuxarm:base-devel
# 使用 WORKDIR 指令可以来指定工作目录（或者称为当前目录），以后各层的当前目录就被改为指定的目录，如该目录不存在， WORKDIR 会帮你建立目录。
WORKDIR /tmp
ENV SHELL /bin/bash
ENV UPDATE_TIME 20220708T10:55:00+08:00
# -S 安装 -y 自动回答yes -u 更新包
RUN yes | pacman -Syu
RUN yes | pacman -S git zsh curl tree which vim
# 管理配置文件
RUN mkdir -p /root/.config
VOLUME [ "/root/.config", "/root/repos", "/root/.vscode-server/extensions", "/root/go/bin", "/root/.local/share/pnpm", "/usr/local/rvm/gems", "/root/.ssh" ]
# end

# zsh  
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
ENV SHELL /bin/zsh 
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
RUN git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
ADD .zshrc /root/.zshrc
ENV SHELL /bin/zsh
# end

# Ruby
ENV LANG=C.UTF-8
ADD rvm-rvm-1.29.12-0-g6bfc921.tar.gz /tmp/rvm-stable.tar.gz
ENV PATH /usr/local/rvm/rubies/ruby-3.0.0/bin:$PATH
ENV PATH /usr/local/rvm/gems/ruby-3.0.0/bin:$PATH
ENV PATH /usr/local/rvm/bin:$PATH
ENV GEM_HOME /usr/local/rvm/gems/ruby-3.0.0
ENV GEM_PATH /usr/local/rvm/gems/ruby-3.0.0:/usr/local/rvm/gems/ruby-3.0.0@global

RUN touch /root/.config/.gemrc; ln -s /root/.config/.gemrc /root/.gemrc;
RUN mv /tmp/rvm-stable.tar.gz/rvm-rvm-6bfc921 /tmp/rvm && cd /tmp/rvm && ./install --auto-dotfiles &&\
		echo "ruby_url=https://cache.ruby-china.com/pub/ruby" > /usr/local/rvm/user/db &&\
		echo 'gem: --no-document --verbose' >> "$HOME/.gemrc"
RUN yes | pacman -S gcc make
ADD openssl-1.1.1q.tar.gz /tmp/openssl
# 这些命令的目的是在安装 OpenSSL 时，
# 指定安装目录、编译、安装 OpenSSL，
# 并创建 /usr/local/openssl/ssl/certs 目录的软链接以便 OpenSSL 正确的查找证书。
RUN cd /tmp/openssl/openssl-1.1.1q &&\
    ./config --prefix=/usr/local/openssl &&\
    make && make install &&\
    rm -rf /usr/local/openssl/ssl/certs && ln -s /etc/ssl/certs /usr/local/openssl/ssl/certs
RUN echo "rvm_silence_path_mismatch_check_flag=1" > /root/.rvmrc &&\
		# 指定 openssl 路径，解决安装 ruby 时 make 指令的报错
    rvm install ruby-3.0.0 --with-openssl-dir=/usr/local/openssl
RUN gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/ &&\
		# Solargraph是一个 Ruby 的智能代码编辑器，可以提供代码自动完成、定义跳转、文档注释等功能。
		# Rubocop是一个 Ruby 代码静态分析工具，可以自动检查代码风格、遵循最佳实践等问题。
		# Rufo是一个 Ruby 代码格式化工具，可以帮助开发人员保持一致的代码格式。
		gem install solargraph rubocop rufo
# end

# Install Go
RUN yes | pacman -S go
# 存储 Go 包和源代码的路径
ENV GOPATH /root/go
# 将 $GOPATH/bin 添加到 PATH 环境变量中，以便可以从命令行访问 Go 安装的二进制文件
ENV PATH $GOPATH/bin:$PATH
# $GOPATH 下创建必要的目录（src 和 bin），并将权限设置为 777 （最高的读4写2执行1权限，分别表示所有者、组用户和其他用户的权限）
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
# Docker 容器上安装 Go 的目录
ENV GOROOT /usr/lib/go
		# 启用了 Go 模块
RUN go env -w GO111MODULE=on &&\
		#	Go 模块代理
    go env -w GOPROXY=https://goproxy.cn,direct &&\
		# gowatch 是一个 Go 语言的自动化构建工具，它可以监控指定的 Go 源代码目录，一旦有代码变更，它会自动重新编译和运行程序。这个工具可以帮助开发者在代码修改后快速验证程序的正确性。
		# gopls 是一个用于 Go 语言的语言服务器，它可以为代码编辑器（如 VS Code、Sublime Text 等）提供智能提示、代码补全、代码重构、代码导航等功能。gopls 的目标是提高 Go 语言开发的效率和开发体验。
		go install github.com/silenceper/gowatch@latest &&\
    go install golang.org/x/tools/gopls@latest
# end

# Dev env for JS
ENV PNPM_HOME /root/.local/share/pnpm
ENV PATH $PNPM_HOME:$PATH
RUN touch /root/.config/.npmrc; ln -s /root/.config/.npmrc /root/.npmrc; \
    yes | pacman -Syy && yes | pacman -S nodejs npm &&\
    npm config set registry=https://registry.npmmirror.com &&\
		corepack enable &&\
		pnpm setup &&\
		pnpm i -g http-server
# end

# nvm
ENV NVM_DIR /root/.nvm
ADD nvm-0.39.1 /root/.nvm/
RUN sh ${NVM_DIR}/nvm.sh &&\
	echo '' >> /root/.zshrc &&\
	echo 'export NVM_DIR="$HOME/.nvm"' >> /root/.zshrc &&\
	echo '[ -s "${NVM_DIR}/nvm.sh" ] && { source "${NVM_DIR}/nvm.sh" }' >> /root/.zshrc &&\
	echo '[ -s "${NVM_DIR}/bash_completion" ] && { source "${NVM_DIR}/bash_completion" } ' >> /root/.zshrc
# end


# tools
# RUN yes | pacman -S fzf openssh exa the_silver_searcher fd rsync &&\
		# ssh-keygen -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key &&\
		# ssh-keygen -t dsa -N '' -f /etc/ssh/ssh_host_dsa_key
# end

# dotfiles
# ADD bashrc /root/.bashrc
# RUN echo '[ -f /root/.bashrc ] && source /root/.bashrc' >> /root/.zshrc; \
    # echo '[ -f /root/.zshrc.local ] && source /root/.zshrc.local' >> /root/.zshrc
# RUN mkdir -p /root/.config; \
    # touch /root/.config/.profile; ln -s /root/.config/.profile /root/.profile; \
    # touch /root/.config/.gitconfig; ln -s /root/.config/.gitconfig /root/.gitconfig; \
    # touch /root/.config/.zsh_history; ln -s /root/.config/.zsh_history /root/.zsh_history; \
    # touch /root/.config/.rvmrc; ln -s /root/.config/.rvmrc /root/.rvmrc; \
    # touch /root/.config/.bashrc; ln -s /root/.config/.bashrc /root/.bashrc.local; \
    # touch /root/.config/.zshrc; ln -s /root/.config/.zshrc /root/.zshrc.local;
# RUN echo "rvm_silence_path_mismatch_check_flag=1" >> /root/.rvmrc
# RUN git config --global core.editor "code --wait"; \
    # git config --global init.defaultBranch main
# end

# ############### disabled
# # # docker in docker
# # RUN yes | pacman -S docker &&\
# # 		mkdir -p /etc/docker &&\
# # 		echo '{"registry-mirrors": ["http://f1361db2.m.daocloud.io"]}' > /etc/docker/daemon.json

# # Rust
# # WORKDIR /tmp
# # ADD .cargo.cn.config /root/.cargo/config
# # ENV RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
# # ENV RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
# # ENV CARGO_HTTP_MULTIPLEXING=false
# # ENV PATH="/root/.cargo/bin:${PATH}"
# # RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
# # end

# # Java
# # RUN yes | pacman -S jre-openjdk-headless jdk-openjdk
# # ENV JAVA_HOME=/usr/lib/jvm/default/
# # ENV PATH=$JAVA_HOME/bin:$PATH
# # end

# # # Python 3 and pip
# # ENV PYTHONUNBUFFERED=1
# # ENV PATH="/root/.local/bin:$PATH"
# # ADD pip.cn.conf /root/.config/pip/pip.conf
# # RUN python -m ensurepip &&\
# # 	python -m pip install --no-cache --upgrade pip setuptools wheel
# # # end
