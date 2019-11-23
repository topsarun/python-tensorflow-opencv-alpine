FROM python:3.7.4-alpine3.10

ENV TENSORFLOW_VERSION=1.13.2 \
    NUMPY_VERSION=1.17.0 \
    JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk \
    BAZEL_VERSION=0.26.1 \
    LOCAL_RESOURCES=4096,2.0,1.0 \
    CC_OPT_FLAGS='-march=native' \
    TF_NEED_JEMALLOC=1 \
    TF_NEED_GCP=0 \
    TF_NEED_HDFS=0 \
    TF_NEED_S3=0 \
    TF_ENABLE_XLA=0 \
    TF_NEED_GDR=0 \
    TF_NEED_VERBS=0 \
    TF_NEED_OPENCL=0 \
    TF_NEED_CUDA=0 \
    TF_NEED_MPI=0

RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
            openblas libpng libjpeg-turbo hdf5 libstdc++ && \
    apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
            --virtual build-deps cmake build-base linux-headers \
            bash wget file openblas-dev freetype-dev libjpeg-turbo-dev \
            libpng-dev hdf5-dev openjdk8 swig zip patch && \
    pip install --no-cache-dir "numpy==$NUMPY_VERSION" h5py && \
    pip install --no-cache-dir --no-deps keras_applications==1.0.8 keras_preprocessing==1.1.0 && \
    echo 'Downloading and compiling bazel' && \
    wget -q "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip" \
         -O bazel.zip && \
    mkdir "bazel-${BAZEL_VERSION}" && \
    unzip -qd "bazel-${BAZEL_VERSION}" bazel.zip && \
    rm bazel.zip && \
    cd "bazel-${BAZEL_VERSION}" && \
    sed -i -e 's/-classpath/-J-Xmx6096m -J-Xms128m -classpath/g' \
        scripts/bootstrap/compile.sh && \
    bash compile.sh && \
    cp -p output/bazel /usr/local/bin/ && \
    cd / && \
    bazel version && \
    echo 'Downloading and compiling tensorflow' && \
    wget -q "https://github.com/tensorflow/tensorflow/archive/v${TENSORFLOW_VERSION}.tar.gz" \
         -O tensorflow.tar.gz && \
    tar xzf tensorflow.tar.gz && \
    rm tensorflow.tar.gz && \
    cd "tensorflow-${TENSORFLOW_VERSION}" && \
    sed -i -e '/define TF_GENERATE_BACKTRACE/d' tensorflow/core/platform/default/stacktrace.h && \
    sed -i -e '/define TF_GENERATE_STACKTRACE/d' tensorflow/core/platform/stacktrace_handler.cc && \
    bazel build -c opt --local_resources "${LOCAL_RESOURCES}" //tensorflow/tools/pip_package:build_pip_package && \
    ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg && \
    cd / && \
    cp /tmp/tensorflow_pkg/*.whl /root && \
    pip install --no-cache-dir /root/*.whl && \
    python -c 'import tensorflow as tf; print(tf.__version__)' && \
    find /usr/lib /usr/local \
         \( -type d -a -name '__pycache__' -o -name '(test|tests)' \) \
         -o \( -type f -a -name '(*.pyc|*.pxd)' -o -name '(*.pyo|*.pyd)' \) \
         -exec rm -rf '{}' + && \
    find /usr/lib* /usr/local/lib* -name '*.so' -print \
       -exec sh -c 'file "{}" | grep -q "not stripped" && strip -s "{}"' \; && \
    apk del build-deps && \
    rm -rf "bazel-${BAZEL_VERSION}" "tensorflow-${TENSORFLOW_VERSION}" \
           /var/tmp/* /usr/share/man /tmp/* /var/cache/apk/* /var/log/* \
           /root/.cache /usr/local/share/man /root/.wget-hsts \
           /usr/local/bin/bazel

ENV LANG=C.UTF-8 \
    OPENCV_VERSION=4.1.1

RUN apk add --update --no-cache \
    # Build dependencies
    build-base clang clang-dev cmake pkgconf wget openblas openblas-dev \
    linux-headers \
    # Image IO packages
    libjpeg-turbo libjpeg-turbo-dev \
    libpng libpng-dev \
    libwebp libwebp-dev \
    tiff tiff-dev \
    jasper-libs jasper-dev \
    openexr openexr-dev \
    # Video depepndencies
    ffmpeg-libs ffmpeg-dev \
    libavc1394 libavc1394-dev \
    gstreamer gstreamer-dev \
    gst-plugins-base gst-plugins-base-dev \
    libgphoto2 libgphoto2-dev && \
    apk add --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
            --update --no-cache libtbb libtbb-dev && \
    # Fix libpng path
    ln -vfs /usr/include/libpng16 /usr/include/libpng && \
    ln -vfs /usr/include/locale.h /usr/include/xlocale.h && \
    # Download OpenCV source
    cd /tmp && \
    wget https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.tar.gz && \
    tar -xvzf ${OPENCV_VERSION}.tar.gz && \
    rm -vrf ${OPENCV_VERSION}.tar.gz && \
    # Configure
    mkdir -vp /tmp/opencv-${OPENCV_VERSION}/build && \
    cd /tmp/opencv-${OPENCV_VERSION}/build && \
    cmake \
        # Compiler params
        -D CMAKE_BUILD_TYPE=RELEASE \
        -D CMAKE_C_COMPILER=/usr/bin/clang \
        -D CMAKE_CXX_COMPILER=/usr/bin/clang++ \
        -D CMAKE_INSTALL_PREFIX=/usr \
        # No examples
        -D INSTALL_PYTHON_EXAMPLES=NO \
        -D INSTALL_C_EXAMPLES=NO \
        # Support
        -D WITH_IPP=NO \
        -D WITH_1394=NO \
        -D WITH_LIBV4L=NO \
        -D WITH_V4l=YES \
        -D WITH_TBB=YES \
        -D WITH_FFMPEG=YES \
        -D WITH_GPHOTO2=YES \
        -D WITH_GSTREAMER=YES \
        # NO doc test and other bindings
        -D BUILD_DOCS=NO \
        -D BUILD_TESTS=NO \
        -D BUILD_PERF_TESTS=NO \
        -D BUILD_EXAMPLES=NO \
        -D BUILD_opencv_java=NO \
        -D BUILD_opencv_python2=NO \
        -D BUILD_ANDROID_EXAMPLES=NO \
        # Build Python3 bindings only
        -D PYTHON3_LIBRARY=`find /usr -name libpython3.so` \
        -D PYTHON_EXECUTABLE=`which python3` \
        -D PYTHON3_EXECUTABLE=`which python3` \
        -D PYTHON3_PACKAGES_PATH=/usr/local/lib/python3.7/site-packages \
        -D BUILD_opencv_python3=YES .. && \
    # Build
    make -j`grep -c '^processor' /proc/cpuinfo` && \
    make install && \
    # Cleanup
    cd / && rm -vrf /tmp/opencv-${OPENCV_VERSION} && \
    apk del --purge build-base clang clang-dev cmake pkgconf wget openblas-dev \
                    openexr-dev gstreamer-dev gst-plugins-base-dev libgphoto2-dev \
                    libtbb-dev libjpeg-turbo-dev libpng-dev tiff-dev jasper-dev \
                    ffmpeg-dev libavc1394-dev \
    rm -vrf /var/cache/apk/*
