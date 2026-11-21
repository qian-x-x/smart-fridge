/*
 * 这个文件：菜谱服务的启动类。它只读不写，提供菜谱目录给前端。
 */

package com.smartfridge.recipe;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "com.smartfridge")
public class RecipeApplication {

    public static void main(String[] args) {
        SpringApplication.run(RecipeApplication.class, args);
    }
}
