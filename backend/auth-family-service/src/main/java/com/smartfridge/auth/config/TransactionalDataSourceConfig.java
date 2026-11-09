package com.smartfridge.auth.config;

import com.zaxxer.hikari.HikariDataSource;
import javax.sql.DataSource;
import org.apache.seata.rm.datasource.DataSourceProxy;
import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.autoconfigure.flyway.FlywayProperties;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.*;

/** Migrate the raw source before AT checks undo_log, including on an empty DB. */
@Configuration
@ConditionalOnProperty(name = "seata.enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties({DataSourceProperties.class, FlywayProperties.class})
public class TransactionalDataSourceConfig {
    @Bean
    @ConfigurationProperties("spring.datasource.hikari")
    HikariDataSource migrationDataSource(DataSourceProperties properties) {
        return properties.initializeDataSourceBuilder().type(HikariDataSource.class).build();
    }

    @Bean(initMethod = "migrate")
    Flyway flyway(@Qualifier("migrationDataSource") DataSource raw, FlywayProperties properties) {
        return Flyway.configure().dataSource(raw)
            .locations(properties.getLocations().toArray(String[]::new))
            .validateOnMigrate(properties.isValidateOnMigrate())
            .baselineOnMigrate(properties.isBaselineOnMigrate()).load();
    }

    @Bean
    @Primary
    @DependsOn("flyway")
    DataSource dataSource(@Qualifier("migrationDataSource") DataSource raw) {
        return new DataSourceProxy(raw);
    }
}
