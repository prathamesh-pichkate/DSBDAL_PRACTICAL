#!/bin/bash

set -e

# === CONFIGURATION ===
HADOOP_VERSION="3.3.6"
HADOOP_URL="https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
HADOOP_DIR="$HOME/hadoop"
JAVA_VERSION="openjdk-8-jdk"
WORDCOUNT_JAVA="WordCount.java"
JAR_NAME="wordcount.jar"
INPUT_DIR="input"
OUTPUT_DIR="output"

echo "===================="
echo "Installing Java 8..."
echo "===================="
sudo apt update
sudo apt install -y "$JAVA_VERSION"

echo "===================="
echo "Downloading Hadoop $HADOOP_VERSION..."
echo "===================="
mkdir -p "$HADOOP_DIR"
cd "$HADOOP_DIR"
wget "$HADOOP_URL" -O hadoop.tar.gz
tar -xzf hadoop.tar.gz --strip-components=1
rm hadoop.tar.gz

# === SET ENVIRONMENT VARIABLES ===
echo "===================="
echo "Configuring environment variables..."
echo "===================="

cat >> ~/.bashrc <<EOF

# HADOOP ENV
export HADOOP_HOME=$HADOOP_DIR
export PATH=\$PATH:\$HADOOP_HOME/bin
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_CLASSPATH=\$(hadoop classpath)
EOF

source ~/.bashrc

export HADOOP_HOME=$HADOOP_DIR
export PATH=$PATH:$HADOOP_HOME/bin
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_CLASSPATH=$(hadoop classpath)

echo "===================="
echo "Creating WordCount.java..."
echo "===================="

# === WORDCOUNT.JAVA ===
cat > "$WORDCOUNT_JAVA" <<EOF
import java.io.IOException;
import java.util.StringTokenizer;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class WordCount {

    public static class TokenizerMapper extends Mapper<Object, Text, Text, IntWritable> {
        private final static IntWritable one = new IntWritable(1);
        private Text word = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            StringTokenizer itr = new StringTokenizer(value.toString());
            while (itr.hasMoreTokens()) {
                word.set(itr.nextToken());
                context.write(word, one);
            }
        }
    }

    public static class IntSumReducer extends Reducer<Text, IntWritable, Text, IntWritable> {
        private IntWritable result = new IntWritable();

        public void reduce(Text key, Iterable<IntWritable> values, Context context)
                throws IOException, InterruptedException {
            int sum = 0;
            for (IntWritable val : values) {
                sum += val.get();
            }
            result.set(sum);
            context.write(key, result);
        }
    }

    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "word count");
        job.setJarByClass(WordCount.class);
        job.setMapperClass(TokenizerMapper.class);
        job.setCombinerClass(IntSumReducer.class);
        job.setReducerClass(IntSumReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
EOF

echo "===================="
echo "Compiling WordCount.java..."
echo "===================="
rm -f *.class "$JAR_NAME"
javac -classpath "$HADOOP_CLASSPATH" -d . "$WORDCOUNT_JAVA"
jar cf "$JAR_NAME" WordCount*.class

# === SETUP INPUT DATA ===
echo "===================="
echo "Preparing input data..."
echo "===================="
rm -rf "$INPUT_DIR" "$OUTPUT_DIR"
mkdir -p "$INPUT_DIR"
echo "hello hadoop world hello hadoop" > "$INPUT_DIR/input.txt"

echo "===================="
echo "Running WordCount job..."
echo "===================="
hadoop jar "$JAR_NAME" WordCount "$INPUT_DIR" "$OUTPUT_DIR"

echo "===================="
echo "Job Output:"
echo "===================="
cat "$OUTPUT_DIR/part-r-00000"
