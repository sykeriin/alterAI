CREATE CONSTRAINT person_id_unique IF NOT EXISTS
FOR (p:Person)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT person_email_unique IF NOT EXISTS
FOR (p:Person)
REQUIRE p.email IS UNIQUE;

CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (p:User)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT founder_id_unique IF NOT EXISTS
FOR (p:Founder)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT recruiter_id_unique IF NOT EXISTS
FOR (p:Recruiter)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT professor_id_unique IF NOT EXISTS
FOR (p:Professor)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT student_id_unique IF NOT EXISTS
FOR (p:Student)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT investor_id_unique IF NOT EXISTS
FOR (p:Investor)
REQUIRE p.id IS UNIQUE;

CREATE INDEX person_skills IF NOT EXISTS
FOR (p:Person)
ON (p.skills);

CREATE INDEX person_interests IF NOT EXISTS
FOR (p:Person)
ON (p.interests);

CREATE INDEX person_location IF NOT EXISTS
FOR (p:Person)
ON (p.location);

CREATE INDEX person_organization IF NOT EXISTS
FOR (p:Person)
ON (p.organization);

