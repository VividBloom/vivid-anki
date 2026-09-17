/**
 * 统一结果类型
 *
 * 目的：让「失败」成为类型系统的一部分。
 * 所有可能失败的业务方法都返回 Result，禁止返回 null 让调用方猜。
 *
 * 错误码见 common/constants/ErrorCode.ets
 */

export class Err {
  code: string;
  message: string;

  constructor(code: string, message: string) {
    this.code = code;
    this.message = message;
  }
}

export class Result<T> {
  readonly ok: boolean;
  private readonly _value: T | null;
  private readonly _err: Err | null;

  private constructor(ok: boolean, value: T | null, err: Err | null) {
    this.ok = ok;
    this._value = value;
    this._err = err;
  }

  static success<T>(v: T): Result<T> {
    return new Result<T>(true, v, null);
  }

  static failure<T>(code: string, message: string): Result<T> {
    return new Result<T>(false, null, new Err(code, message));
  }

  /**
   * 取成功值。
   *
   * 【修复说明】原实现以 `_value === null` 判定失败，导致
   * Result.success(null)（例如「查最近一条复习日志，没有结果」）
   * 在读取 value 时抛异常 —— 而那本是一个正常的业务分支。
   * 失败与否只应由 ok 判定，null 也可能是合法的成功值。
   */
  get value(): T {
    if (!this.ok) {
      throw new Error('Result 为失败态，不应读取 value：' + (this._err?.message ?? ''));
    }
    return this._value as T;
  }

  get error(): Err {
    if (this._err === null) {
      throw new Error('Result 为成功态，不应读取 error');
    }
    return this._err;
  }

  /** 失败时返回默认值，用于「失败了也不该崩」的场景 */
  getOrElse(fallback: T): T {
    return this.ok ? (this._value as T) : fallback;
  }
}
