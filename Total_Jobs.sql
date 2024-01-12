CREATE DEFINER=`root`@`localhost` PROCEDURE `TotalJobsStats`(
    IN timeLabel VARCHAR(60),
    IN geoLabel VARCHAR(60)
)
proc_Exit:BEGIN    DECLARE start_date DATE;

    DECLARE end_date DATE;

    DECLARE table_check_sql VARCHAR(1000);


    -- Check if the sql_log table exists, and create it if it doesn't    
    CREATE TABLE IF NOT EXISTS sql_log (id INT AUTO_INCREMENT PRIMARY KEY,log_message TEXT, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP    );

    -- Initialize table_count to 0    
    SET @table_count = 0;


    -- Check if the table generate_stats.json_daily_run exists    
    SET @table_check_sql = CONCAT('SELECT COUNT(*) FROM generate_stats.json_daily_run INTO @table_count');

    PREPARE table_check_stmt FROM @table_check_sql;

    EXECUTE table_check_stmt;

    DEALLOCATE PREPARE table_check_stmt;


    -- If the table is empty, log a message and exit   
    IF @table_count = 0 THEN

        INSERT INTO sql_log (log_message) VALUES ('The table generate_stats.json_daily_run is empty');

        LEAVE proc_Exit;

    END IF;

	-- Input validation for timeLabel
    IF timeLabel NOT IN ('month', 'year') AND NOT REGEXP_LIKE(timeLabel, '^\d{4}-\d{2}-\d{2}, \d{4}-\d{2}-\d{2}') THEN
        -- Handle invalid timeLabel input
        INSERT INTO sql_log (log_message) VALUES ('Invalid timeLabel input');
        LEAVE proc_Exit;
    END IF;

    -- Parse date range if provided
    IF REGEXP_LIKE(timeLabel, '^\d{4}-\d{2}-\d{2}, \d{4}-\d{2}-\d{2}$') THEN
        SET @start_date = CAST(SUBSTRING_INDEX(timeLabel, ', ', 1) AS DATE);
        SET @end_date = CAST(SUBSTRING_INDEX(timeLabel, ', ', -1) AS DATE);
    
        -- Check that start date is less than end date
        IF @start_date >= @end_date THEN
            INSERT INTO sql_log (log_message) VALUES ('Invalid date range: Start date must be less than end date');
            LEAVE proc_Exit;
        END IF;
    END IF;
	
	IF geoLabel NOT IN ('region', 'country', 'industry', 'company', 'industry-role', 'company-role', 'skills') THEN
        -- Handle invalid geoLabel input
        INSERT INTO sql_log (log_message) VALUES ('Invalid geoLabel input');
        LEAVE proc_Exit;
    END IF;

	IF timeLabel='month' and geoLabel ='region' then
		SELECT month,region,sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE region!='none'
		GROUP BY month,region
		ORDER BY month ,Total_Jobs DESC;
	ELSEIF timeLabel='year' and geoLabel='region' then
		SELECT year,region,sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE region!='none'
		GROUP BY year,region
		ORDER BY year ,Total_Jobs DESC;
	ELSEIF timeLabel='month' and geoLabel='country' then
		SELECT month,country, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY month,country    
		ORDER BY month ,Total_Jobs DESC;
	ELSEIF timeLabel='year' and geoLabel='country' then
		SELECT year,country, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY year,country    
		ORDER BY year ,Total_Jobs DESC;  
	ELSEIF timeLabel='month' and geoLabel='industry' then
		SELECT month,country,industry, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY month,country,industry    
		ORDER BY month,Total_Jobs DESC;    
	ELSEIF timeLabel='year' and geoLabel='industry' then
		SELECT year,country,industry, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY year,country,industry    
		ORDER BY year ,Total_Jobs DESC; 
	ELSEIF timeLabel='month' and geoLabel='company' then
		SELECT month,country,industry,company, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY month,country,industry,company    
		ORDER BY month,Total_Jobs DESC;       
	ELSEIF timeLabel='year' and geoLabel='company' then
		SELECT year,country,industry,company, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY year,country,industry,company    
		ORDER BY year ,Total_Jobs DESC;    
	ELSEIF timeLabel='month' and geoLabel='industry-role' then
		SELECT month,country,industry,`job-role`, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY month,country,industry,`job-role`    
		ORDER BY month,Total_Jobs DESC;  
	ELSEIF timeLabel='year' and geoLabel='industry-role' then
		SELECT year,country,industry,`job-role`, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY year,country,industry,`job-role`   
		ORDER BY year ,Total_Jobs DESC;     
	ELSEIF timeLabel='month' and geoLabel='company-role' then
		SELECT month,country,industry,company,`job-role`, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY month,country,industry,company,`job-role`    
		ORDER BY month,Total_Jobs DESC; 
	ELSEIF timeLabel ='year' and geoLabel='company-role' then
		SELECT year,country,industry,company,`job-role`, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY year,country,industry,company,`job-role`   
		ORDER BY year ,Total_Jobs DESC;  
	 ELSEIF timeLabel ='month' and geoLabel='skills' then
		SELECT month,country,industry,company,Top_5_skills,sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY month,country,industry,company,Top_5_skills
		ORDER BY month ,Total_Jobs DESC; 
	 ELSEIF timeLabel ='year' and geoLabel='skills' then
		SELECT year,country,industry,company,Top_5_skills, sum(Number_of_Jobs) as Total_Jobs FROM generate_stats.json_daily_run
		WHERE country!='none'
		GROUP BY year,country,industry,company,Top_5_skills   
		ORDER BY year ,Total_Jobs DESC;       
		
	ELSE        
          
			SET @start_date = SUBSTRING_INDEX(timeLabel, ', ', 1);
			SET @end_date = SUBSTRING_INDEX(timeLabel, ', ', -1);
			IF geoLabel='region' THEN
            
				SELECT  region, SUM(Number_of_Jobs) as Total_Jobs
				FROM generate_stats.json_daily_run
				WHERE region != 'none' 
				AND date BETWEEN @start_date AND @end_date
				GROUP BY region
				ORDER BY Total_Jobs DESC;
                
			elseif geoLabel='country' then 
			SELECT  country, SUM(Number_of_Jobs) as Total_Jobs
				FROM generate_stats.json_daily_run
				WHERE country != 'none' 
				AND date BETWEEN @start_date AND @end_date
				GROUP BY country
				ORDER BY Total_Jobs DESC;
	END if;
	end if;
END