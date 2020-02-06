--------------------------------- OIE-------------------------------------
--------------------------- REQUEST DESCRIPTION---------------------------
/*
Data prepared for: Tables used in Power BI Program Assessment Visualization
Project. There are five queries that capture data from various place that
can be used to assess the composition, success and trends within programs,
departments, or colleges.

Used On Power BI 'Program Assessment Visualization' 

Request(s): 

Author: Madison Miatke
Date Created: 1-24-2020

*/

----------------------------- BEGIN SCRIPT HERE---------------------------
USE MM_DB
GO

--USED TO RESET VIEWS WHEN CODE IS RUN--
DROP VIEW [dbo].[Program_Composition_View]
DROP VIEW [dbo].[Program_Retention_View]
DROP VIEW [dbo].[Program_Gend_Ethn_View]
DROP VIEW [dbo].[Program_Admission_View]
DROP VIEW [dbo].[Program_Graduation_View]
GO

/*PROGRAM TRENDS/DATA 
 *  CAPTURES basic data about each program for each term                         *
 *  WITH THE FIELDS College, Department, Major, Degree Type, Term, New, Total, Graduates, GPA *
 *  USING a list of terms, Sure_Enrollments, DegreesAwardedFile, lkp NJIT_Program_Codes, lkp School*/
CREATE VIEW [Program_Composition_View] AS
	SELECT 
		f1.College, f1.Department, f1.Major, f1.DegType, f1.Term,
		COUNT(f1.SID) AS Total,
		ISNULL(f0.Cnt,0) AS New,  
		ISNULL(f4.gradCount,0) AS Graduates,
		ISNULL(f5.overallGPA,0) AS Average_Overall_GPA
	
		FROM WORKDB..[SURE_ENROLLMENTS] f1
	
		LEFT JOIN ( --Freshemen Count--
			SELECT 
				Term, MAJOR, DEGTYPE,
				Count(SID) AS Cnt
				FROM WORKDB..[SURE_ENROLLMENTS]
				WHERE ftftu=1 OR (REGSTAT=1 AND (STUDENT_LEVEL='G' OR STUDENT_LEVEL = 'D'))
				GROUP BY MAJOR, DEGTYPE,Term
		) f0 ON f0.Term=f1.Term AND f0.Major=f1.MAJOR AND f0.DegType=f1.DegType

		LEFT JOIN ( --Graduates Count--
			SELECT 
				AY,SHRDGMR_MAJR_CODE_1, SHRDGMR_DEGC_CODE,
				Count(SID) AS gradCount
				FROM WORKDB..[DegreesAwardedFile]
				GROUP BY SHRDGMR_MAJR_CODE_1, SHRDGMR_DEGC_CODE, AY
		) f4 ON ('F' + f4.AY)=f1.Term AND f4.SHRDGMR_MAJR_CODE_1=f1.MAJOR AND f4.SHRDGMR_DEGC_CODE=f1.DegType

		LEFT JOIN ( --Overall Avg GPA--
			SELECT Term, MAJOR, DEGTYPE,
				round(avg(GPA),3) AS overallGPA
				FROM WORKDB..[SURE_ENROLLMENTS]
				WHERE GPA != 0
				GROUP BY MAJOR, DEGTYPE,Term
		) f5 ON f5.Term=f1.Term AND f5.Major=f1.MAJOR AND f5.DegType=f1.DegType

		--Major Codes to Major Names--
		LEFT JOIN 
			Workdb..[lkp NJIT_Program_Codes] f2 
		ON f1.MAJOR=f2.STVMAJR_CODE

		--College Codes to College Names--
		LEFT JOIN 
			Workdb..[lkp Schools] f3 
		ON f1.MAJOR=f3.[School Code]

		--For data only from terms in @TERMS--
		WHERE f1.Term IN ('F2014','F2015','F2016','F2017','F2018') --UPDATE: Add more years as SURE_ENROLLMENTS is updated
		GROUP BY f1.College,f1.Department,f1.Major,f1.Degtype, f1.Term, f1.Major,f1.DegType, f0.Cnt, f4.gradCount, f5.overallGPA
GO
/*PROGRAM RETENTION 
 *  CAPTURES retention and continuation rates about each program for each cohort          *
 *  WITH THE FIELDS College, Department, Major, Degree Type, Term, Initial_Enrollment,    *
 *                  Fall_2015_Continue, Retained_2015, Fall_2016_Continue, Retained_2016  *
 *                  Fall_2017_Continue, Retained_2017, Fall_2018_Continue, Retained_2018, *
 *                  Fall_2019_Continue, Retained_2019                                     *
 *  USING Sure_Enrollments, SURE Enrollment F2019 10D                                     */

CREATE VIEW [Program_Retention_View] AS
	SELECT 
		f1.College, f1.Department, f1.Major, f1.DegType, f1.Term, count(f1.SID) AS Initial_Enrollment, 
		ISNULL(f2.F15_Continue,0) AS Fall_2015_Continue, round(cast(ISNULL(f2.F15_Continue,0) AS FLOAT)/count(f1.SID),4) AS Retained_2015,
		ISNULL(f3.F16_Continue,0) AS Fall_2016_Continue, round(cast(ISNULL(f3.F16_Continue,0) AS FLOAT)/count(f1.SID),4) AS Retained_2016,
		ISNULL(f4.F17_Continue,0) AS Fall_2017_Continue, round(cast(ISNULL(f4.F17_Continue,0) AS FLOAT)/count(f1.SID),4) AS Retained_2017,
		ISNULL(f5.F18_Continue,0) AS Fall_2018_Continue, round(cast(ISNULL(f5.F18_Continue,0) AS FLOAT)/count(f1.SID),4) AS Retained_2018,
		ISNULL(f6.F19_Continue,0) AS Fall_2019_Continue, round(cast(ISNULL(f6.F19_Continue,0) AS FLOAT)/count(f1.SID),4) AS Retained_2019
		--UPDATE: Add f7 with F20_continue and retained_2020 (follow pattern)

		FROM WORKDB..[SURE_ENROLLMENTS] f1

		LEFT JOIN ( --Capture 2015 retention data
			SELECT 
				Term, Major, DegType, 
				count(SID) AS F15_Continue 

				FROM WORKDB..[SURE_ENROLLMENTS] p
				WHERE (ftftu=1 OR (REGSTAT=1 AND (STUDENT_LEVEL='G' OR STUDENT_LEVEL = 'D'))) 
					AND term < 'F2015' 
					AND SID IN 
					(
						SELECT SID 
							FROM WORKDB..[SURE_ENROLLMENTS]
							WHERE Term = 'F2015' AND Major = p.Major AND DegType = p.DegType
					)
				GROUP BY Major, DegType, Term
		)f2 ON f2.Term=f1.Term AND f2.Major = f1.Major AND f2.DEGTYPE = f1.DEGTYPE
	
		LEFT JOIN ( --Capture 2016 retention data
			SELECT
				Term, Major, DegType, 
				count(SID) AS F16_Continue

				FROM WORKDB..[SURE_ENROLLMENTS] p
				WHERE (ftftu=1 OR (REGSTAT=1 AND (STUDENT_LEVEL='G' OR STUDENT_LEVEL = 'D'))) 
					AND term < 'F2016' 
					AND SID IN 
					(
						SELECT SID 
							FROM WORKDB..[SURE_ENROLLMENTS] 
							WHERE Term = 'F2016' AND Major = p.Major AND DegType = p.DegType 
					)
				GROUP BY Major, DegType, Term
		)f3 ON f3.Term=f1.Term AND f3.Major = f1.Major AND f3.DEGTYPE = f1.DEGTYPE

		LEFT JOIN ( --Capture 2017 retention data
			SELECT 
				Term, Major, DegType, 
				count(SID) AS F17_Continue 

				FROM WORKDB..[SURE_ENROLLMENTS] p
				WHERE (ftftu=1 or (REGSTAT=1 AND (STUDENT_LEVEL='G' OR STUDENT_LEVEL = 'D'))) 
					AND term < 'F2017' 
					AND SID IN (
						SELECT SID 
							FROM WORKDB..[SURE_ENROLLMENTS] 
							WHERE Term = 'F2017' AND Major = p.Major AND DegType = p.DegType
					)
				GROUP BY Major, DegType, Term
		)f4 ON f4.Term=f1.Term AND f4.Major = f1.Major AND f4.DEGTYPE = f1.DEGTYPE


		LEFT JOIN ( --Capture 2018 retention data
			SELECT 
				Term, Major, DegType, 
				count(SID) AS F18_Continue 
		
				FROM WORKDB..[SURE_ENROLLMENTS] p
				WHERE (ftftu=1 or (REGSTAT=1 AND (STUDENT_LEVEL='G' OR STUDENT_LEVEL = 'D'))) 
					AND term < 'F2018' 
					AND SID IN (
						SELECT SID 
							FROM WORKDB..[SURE_ENROLLMENTS] 
							WHERE Term = 'F2018' AND Major = p.Major AND DegType = p.DegType
					)
				GROUP BY Major, DegType, Term
		)f5 ON f5.Term=f1.Term AND f5.Major = f1.Major AND f5.DEGTYPE = f1.DEGTYPE

		LEFT JOIN( --Capture 2019 retention data
			SELECT
				Term, Major, DegType, 
				count(SID) AS F19_Continue 

				FROM WORKDB..[SURE_ENROLLMENTS] p
				WHERE (ftftu=1 OR (REGSTAT=1 AND (STUDENT_LEVEL='G' OR STUDENT_LEVEL = 'D'))) 
					AND term < 'F2019' 
					AND SID IN (
						SELECT SID 
							FROM WORKDB..[SURE Enrollment F2019 10D] --UPDATE: switch to SURE_ENROLLMENTS after it has been updated with F2019 data
							WHERE Major = p.Major AND DegType = p.DegType
					)	
				GROUP BY Major, DegType, Term
		)f6 ON f6.Term=f1.Term AND f6.Major = f1.Major AND f6.DEGTYPE = f1.DEGTYPE

		--UPDATE: after sure_enrollments is updated, follow pattern for 2019 and use [SURE Enrollment F2020 10D]

		WHERE ftftu=1
			OR (REGSTAT=1 AND (STUDENT_LEVEL='G' OR STUDENT_LEVEL = 'D'))
		GROUP BY f1.College,f1.Department,f1.Major,f1.Degtype, f1.Term, F15_Continue, F16_Continue, F17_Continue, F18_Continue, F19_Continue --UPDATE: Add F20_Continue
GO

/*GENDER/ETHNICITY 
 *  CAPTURES gender and ethnicity of students in each program for each term    *
 *  WITH THE FIELDS College, Department, Major, Degree Type, Ethnicity, Gender *
 *  USING Sure_Enrollments                                                     */
 CREATE VIEW [Program_Gend_Ethn_View] AS
	 SELECT 
		College, Department, 
		Major, DegType, Term,
		ISNULL(REPLACE(	--Replace statement used to correct for old data labeling ethnicities slightly differently then current standards
			REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(Ethnicity,'Hispanic','Hisp')
							,'Hisp','Hispanic')
						,'NULL','Unknown')
					,'Am.Ind./ Al.Nat.','AmInd')
				,'Native American','AmInd')
			,'African American','Black')
		,'Nat.Haw./ Pac.Isl.','NatHaw')
		,'Unknown') AS Ethnicity,
		Gender

		FROM WORKDB..[SURE_ENROLLMENTS] f1
GO
	--UPDATE: Up to date aslong as sure_enrollments is up to date

/*ADMISSIONS 
 *  CAPTURES various data on applicants that were accepted to each program each year            *
 *  WITH THE FIELDS Year, College, Department, Major, Degree Type, Level, Admition Description, * 
 *                  SAT Math Score, SAT Reading Score, Ethnicity, Gender                        *
 *  USING Admissions_2014, Admissions_2015, Admissions_2016, Admissions_2017, Admissions_2018   */  

CREATE VIEW [Program_Admission_View] AS
	SELECT --Capture Admission data for 2014
		'2014' AS Yr, 
		UPPER(g.School) AS College, Dept AS Department, Major, DEG AS DegType,
		Levl, AdmitDesc,
		SAT_M, SAT_V_Crit_Read,
		d.gender_description AS Gender, ISNULL(ETHNICITY,'Unknown') AS Ethnicity

		FROM WORKDB..[Admissions_2014] t

		LEFT JOIN( --Change school code to full school name using lkp table
			SELECT 
				[School Code], School 
			
				FROM WorkDB..[lkp Schools]
		) g ON g.[School Code] = t.SCHOOL

		LEFT JOIN( --Change gender code to gender name using lkp table
			SELECT 
				gender,gender_description
			
				FROM WorkDB..[lkp Gender_Code]
		)d ON d.gender = t.GENDER

	UNION

	SELECT --Capture Admission data for 2015
		'2015' AS YR,
		UPPER(g.School) AS COLLEGE, DEPT, DEG, MAJOR,
		LEVL, ADMITDESC,
		SAT_M, SAT_V_CRIT_READ,
		d.gender_description AS GENDER, ISNULL(ETHNICITY,'Unknown') AS ETHNICITY

		FROM WORKDB..[Admissions_2015] t

		LEFT JOIN( --Change school code to full school name using lkp table
			SELECT 
				[School Code], School 
			
				FROM WorkDB..[lkp Schools]
		) g ON g.[School Code] = t.SCHOOL

		LEFT JOIN( --Change gender code to gender name using lkp table
			SELECT 
				gender,gender_description
			
				FROM WorkDB..[lkp Gender_Code]
		)d ON d.gender = t.GENDER

	UNION

	SELECT --Capture Admission data for 2016
		'2016' AS YR,
		UPPER(g.School) AS COLLEGE, DEPT, DEG, MAJOR,
		LEVL, ADMITDESC,
		SAT_M, SAT_V_CRIT_READ,
		d.gender_description AS GENDER, ISNULL(ETHNICITY,'Unknown') AS ETHNICITY

		FROM WORKDB..[Admissions_2016] t

		LEFT JOIN( --Change school code to full school name using lkp table
			SELECT 
				[School Code], School 
			
				FROM WorkDB..[lkp Schools]
		) g ON g.[School Code] = t.SCHOOL

		LEFT JOIN( --Change gender code to gender name using lkp table
			SELECT 
				gender,gender_description
			
				FROM WorkDB..[lkp Gender_Code]
		)d ON d.gender = t.GENDER

	UNION

	SELECT --Capture Admission data for 2017
		'2017' AS YR,
		UPPER(e.School) AS COLLEGE, DEPT, DEG, MAJOR,
		LEVL, ADMITDESC,
		SAT_M, SAT_R AS SAT_V_CRIT_READ,
		d.gender_description AS GENDER, ISNULL(ETHNICITY,'Unknown') AS ETHNICITY

		FROM WORKDB..[Admissions_2017] f

		LEFT JOIN ( --Change application status code to full description using lkp table
			SELECT 
				AppStatCode, 
				AppStatus AS ADMITDESC

				FROM WORKDB..[lkp Application Status Code]
		) g ON f.APDC = g.AppStatCode
 
		LEFT JOIN( --Change school code to full school name using lkp table
			SELECT 
				[School Code], School 
			
				FROM WorkDB..[lkp Schools]
		) e ON e.[School Code] = f.SCHOOL

		LEFT JOIN( --Change gender code to gender name using lkp table
			SELECT 
				gender,gender_description
			
				FROM WorkDB..[lkp Gender_Code]
		)d ON d.gender = f.GENDER

	UNION

	SELECT --Capture Admission data for 2018
		'2018' AS YR,
		UPPER(e.School) AS COLLEGE, DEPT, DEG, MAJOR,
		LEVL, ADMITDESC,
		SAT_M, SAT_R AS SAT_V_CRIT_READ,
		d.gender_description AS GENDER, ISNULL(ETHNICITY,'Unknown') AS ETHNICITY

		FROM WORKDB..[Admissions_2018] f

		LEFT JOIN ( --Change application status code to full description using lkp table
			SELECT 
				AppStatCode, 
				AppStatus AS ADMITDESC

				FROM WORKDB..[lkp Application Status Code]
		) g ON f.APDC = g.AppStatCode

		LEFT JOIN( --Change school code to full school name using lkp table
			SELECT 
				[School Code], School 
			
				FROM WorkDB..[lkp Schools]
		) e ON e.[School Code] = f.SCHOOL
	
		LEFT JOIN( --Change gender code to gender name using lkp table
			SELECT 
				gender,gender_description
			
				FROM WorkDB..[lkp Gender_Code]
		)d ON d.gender = f.GENDER

		--UPDATE: Follow 2017/2018 pattern to add 2019 admissions after it is completed
GO

/*GRADUATIONS 
 *  CAPTURES basic data on the graduating students in each program each year                    *
 *  WITH THE FIELDS Year, College Code, College, Dept Code, Major Code, Degree Code, Level,     *
 *                  Gender, GPA                                                                 * 
 *  USING DegreesAwardedFile, lkp Schools                                                       */
CREATE VIEW [Program_Graduation_View] AS
	SELECT 
		AY AS Yr, 
		UPPER(g.School) AS College,
		SHRDGMR_DEPT_CODE AS Department,
		SHRDGMR_MAJR_CODE_1 AS Major, 
		SHRDGMR_DEGC_CODE AS DegType, 
		SHRDGMR_LEVL_CODE AS Levl,
		REPLACE(REPLACE(REPLACE(GENDER,'M','Male'),'F','Female'),'N','Other') AS Gender,
		ACCUMGPA/100 AS GPA

		FROM WorkDB..[DegreesAwardedFile] f

		LEFT JOIN( --Change school code to full school name using lkp table
			SELECT 
				[School Code], School 
			
				FROM WorkDB..[lkp Schools]
		) g ON g.[School Code] = REPLACE(REPLACE(f.SHRDGMR_COLL_CODE_1,'AR','AD'),'IN','CS') --Use replace to account for College Codes that aren't in the lkp table

		WHERE AY != 2020 --UPDATE: Change to 2021 after Spring 2020 graduations are added
GO

-- PRINT OUT TABLES --
SELECT * FROM [dbo].[Program_Composition_View]
SELECT * FROM [dbo].[Program_Retention_View]
SELECT * FROM [dbo].[Program_Gend_Ethn_View]
SELECT * FROM [dbo].[Program_Admission_View]
SELECT * FROM [dbo].[Program_Graduation_View]