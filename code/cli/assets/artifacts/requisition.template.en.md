# Requisition

<!-- macss:lang=en · Language of this requisition and ALL its derived artifacts (specification, issues, plans). Keep consistent. Not rendered in the PDF/DOCX. -->

> A **requisition** is a formal request that a change be made — the business need that originates the work. (Spanish: *solicitud*.)

> **All fields are mandatory.**
> Structure based on *Gap Analysis* — BABOK® v3 (IIBA), ch. 8.
> Domain terminology aligned with *Ubiquitous Language* — Domain-Driven Design (Eric Evans, 2003).

## Metadata

| Field       | Value                              |
| ----------- | ---------------------------------- |
| System      | <!-- official catalog value -->    |
| Project     | <!-- project name -->              |
| Requester   | <!-- name — area -->               |
| Date        | {{DATE}}                           |
| Contact     | <!-- name and contact channel -->  |

**Urgency:**

- [ ] Critical
- [ ] High
- [ ] Normal

## 1. Need and value

<!-- BABOK® — Business Need. Three short questions, one sentence each.
     Only you have these answers; nobody can write them for you. -->

**What problem does this solve?**

> **Example:** *"Invoice records are lost when two analysts edit the file at the same time."*

**Who does it affect?**

> **Example:** *"The four Accounts Payable analysts, every day."*

**What happens if it is not done?**

> **Example:** *"We keep redoing the monthly close and carrying differences that surface late."*

<!-- The fourth question ---how will we know it worked--- does not belong here:
     it comes out of the analysis with QA and lands in the specification,
     because turning it into something observable is engineering work, not the
     requester's. -->

## 2. Current state

<!-- BABOK® — Current State Description -->

Describe how the thing you want to change is done **today**. If it is something new that does not exist, write: *"Does not currently exist"*.

> **Example:** *"Invoice registration is currently done in a shared Excel sheet. Each analyst opens the file, finds the last row, and enters the data manually. Sometimes two people edit at once and records are lost."*

<!-- Use the domain's ubiquitous language (Ubiquitous Language — DDD). -->

## 3. Desired state

<!-- BABOK® — Future State Description -->

Describe how you **want it to work** in the future. You do not need to give the technical solution, only the expected result.

> **Example:** *"The system must have an invoice registration form with fields: number, amount, supplier, and date. It must not allow duplicate records. On save, the information must be available to all users without risk of loss."*

<!-- Use the domain's ubiquitous language (Ubiquitous Language — DDD). -->

## Annexes

<!-- Screenshots, documents, examples, mockups, diagrams, prior emails, or any supporting material. -->
