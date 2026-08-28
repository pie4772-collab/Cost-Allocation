import { describe, it, expect } from "vitest";
import { userCreateSchema, userUpdateSchema } from "../validations";

describe("userCreateSchema", () => {
  it("accepts a valid new user", () => {
    const parsed = userCreateSchema.parse({
      email: "team@kbigrp.com",
      name: "홍길동",
      password: "password1",
      roles: ["Viewer"],
    });
    expect(parsed.email).toBe("team@kbigrp.com");
  });

  it("rejects short passwords", () => {
    const result = userCreateSchema.safeParse({
      email: "team@kbigrp.com",
      name: "홍길동",
      password: "short",
      roles: ["Viewer"],
    });
    expect(result.success).toBe(false);
  });

  it("requires at least one role", () => {
    const result = userCreateSchema.safeParse({
      email: "team@kbigrp.com",
      name: "홍길동",
      password: "password1",
      roles: [],
    });
    expect(result.success).toBe(false);
  });
});

describe("userUpdateSchema", () => {
  it("allows optional password", () => {
    const parsed = userUpdateSchema.parse({ name: "이재용" });
    expect(parsed.name).toBe("이재용");
  });
});
